using JuMP, Gurobi, Cbc
import XLSX


#### read data ####
xf = XLSX.readxlsx("../data/data2_6.xlsx")
l = xf["General!B1"]     # work day duration
N = xf["General!B3"] + 1  # number of clients + 1
M = xf["General!B2"]  # number of providers
# + 1 is for including the headquarter (HS14)

# Clients
s = xf["Clients!A2:A$N"]   # client service start times
d = vcat([0], xf["Clients!B2:B$N"])   # durations for clients, set d[1] = 0 for HS14


# Providers
w = xf["Providers!B2:B$(M+1)"]  # start time of providers
f = xf["Providers!A2:A$(M+1)"]  # hiring cost of providers

# make separate s vector for each provider, inserting into the first element the provider's work start time
s_test = ones(M, N)
for k in 1:M
    global s_test[k,:] = vcat([w[k]], s)
end
s = s_test

# Distances
t = xf["Distances"][:]  # 2-d array of travel times
##########



model = Model();
set_optimizer(model, Gurobi.Optimizer);
#(13)
@variable(model, x[1:N, 1:N, 1:M], Bin)
# subtour constraint variables using u
@variable(model, 1 <= u[1:N, 1:M] <= N-1)

######################## routing constraints ######################

# (2) each client served once by one provider
@constraint(model, served[j in 2:N], sum(x[i,j,k] for i in 1:N for k in 1:M) == 1)

# (3) route continuity
@constraint(model, continuity[p in 2:N, k in 1:M], sum(x[i,p,k] for i in 1:N) == sum(x[p,j,k] for j in 1:N) )

# (4) not all providers need to leave 14HS (and start working)
@constraint(model, leave_depot[k in 1:M], sum(x[1,j,k] for j in 2:N) <= 1)

# (5) not all providers need to return to 14HS (i.e. they didn't leave 14HS in the first place)
#@constraint(model, return_depot[k in 1:M], sum(x[i,1,k] for i in 2:N) <= 1)

# (6) no self looping
#@constraint(model, diag[k in 1:M], sum(x[i,i,k] for i in 1:N) == 0)

# (7) at least 1 provider must leave 14HS and start working to serve clients
@constraint(model, sum(x[1,j,k] for j in 2:N for k in 1:M) >= 1)

# (8) all providers must start their work at 14HS, if they do work
#@constraint(model, large[k in 1:M], sum(x[i,j,k] for i in 2:N for j in 2:N) <= L*sum(x[1,j,k] for j in 2:N))

#(9) subtour elimination for each provider
for k in 1:M
    for i in 2:N
        for j in 2:N
            @constraint(model, u[i,k] - u[j,k] + (N-1) * x[i,j,k] <= (N-1) - 1 )
        end
    end
end

######################## end routing constraints ######################


######################## time constraints ######################

# (10) initial client service times
@constraint(model, start[j in 2:N, k in 1:M], x[1,j,k]*(s[k,1] + t[1,j] + d[1]) <= s[k,j])


# (11) in between start and end of work, service times
@constraint(model, bet[i in 2:N, j in 2:N, k in 1:M], x[i,j,k]*(s[k,i] + t[i,j] + d[i]) <= s[k,j])


# (12) come back to 14HS by hour l.
@constraint(model, endofwork[i in 2:N, k in 1:M], x[i,1,k]*(s[k,i] + t[i,1] + d[i]) <= l)

######################## end time constraints ######################

# newer objective to minimise total cost based on hours of work.
### Note. the max() function inside the objective can only be solved by Gurobi solver (Cbc cannot solve)
### This objective is for the HOURLY COST as a small extension to part 1 in PART2...
# uncomment this objective and comment the objective below to use this objective for part 2
#@objective(model, Min, sum(x[1,j,k]*f[k]*(sum(x[p,q,k]*(t[p,q] + d[p] + max(0, s[k,q] - s[k,p] - t[p,q] - d[p]) ) for p in 1:N for q in 1:N)) for j in 2:N for k in 1:M))

# original non-hourly objective for part 1
### This objective is for original PART 1
@objective(model, Min, sum(f[k]*x[1,j,k] for j in 1:N for k in 1:M))


optimize!(model)




# see which providers are chosen to provide service.
for k in 1:M
    if sum(value.(x[1,:,k])) == 1
        println("Provider $k provides service.")
        println("Provider $k costs $(f[k]) per hour.")
        # come back hr
        for i in 2:N
            if value.(x[i,1,k]) == 1
                println("Provider $k comes back to 14HS at $(t[i,1] + s[k,i] + d[i])hr. \n")
                break # added
            end
        end
    end
end

# Given N: number of clients+1, and provider number k, find the path
### So if you found that providers 2, 3, 4 and 5 are chosen to work, run get_path(N, 2), get_path(N, 3) etc.
function get_path(N, k)
    path = []
    for j in 2:N
        if value.(x[1,j,k]) == 1
            println("\nstart of path")
            println(1, " => ")
            path = vcat(path, [1])
            println(j, " => ")
            path = vcat(path, [j])
            i = j
            while value.(x[i,1,k]) == 0
                for m in 2:N
                    if value.(x[i,m,k]) == 1
                        println(m, " => ")
                        path = vcat(path, [m])
                        i = m
                        break
                    end
                end
            end
            println(1)
            path = vcat(path, [1])
            println("end of path.... or in client index below (not location)")
        end
    end

    for j in 2:N
        if value.(x[1,j,k]) == 1
            println("\nstart of path")
            println(0, " => ")
            println(j-1, " => ")
            i = j
            while value.(x[i,1,k]) == 0
                for m in 2:N
                    if value.(x[i,m,k]) == 1
                        println(m-1, " => ")
                        i = m
                        break
                    end
                end
            end
            println(0)
            println("end of path (in client index)")
        end
    end
    return path
end



k = 8
path = get_path(N, k)

function overview(path, k)
    println("$(s[k,1])hr: Becomes available, leaves to location $(path[2]).")
    for i in 2:length(path)-1
        println("$(s[k,path[i-1]]+t[path[i-1], path[i]] + d[path[i-1]])hr: Arrived at location $(path[i]).")
        if s[k,path[i-1]]+t[path[i-1], path[i]] + d[path[i-1]] != s[k,path[i]]
            println("   Arrived early... Wait until service start time.")
        end
        println("$(s[k,path[i]])hr: Serve for $(d[path[i]]) hrs.")
        println("$(s[k,path[i]]+d[path[i]])hr: Finished service. Leave to location $(path[i+1]).")
    end
    println("$(s[k,path[length(path)-1]] + d[path[length(path)-1]] + t[path[length(path)-1], 1])hr: Arrived at location 1 (14HS).\n")
end

# print the overview of the path for provider k, where 'path' is found above using get_path(N,k)
path = [1 7 1]
k = 2
overview(path, k)

# find the number of worked hours = provider come back time (to 14HS) -  provider start time (w_k)
### Dont really need this.
worked_hr = s[k,path[length(path)-1]] + d[path[length(path)-1]] + t[path[length(path)-1], 1] - s[k,1]
println("Provider $k worked for $worked_hr hours.")
