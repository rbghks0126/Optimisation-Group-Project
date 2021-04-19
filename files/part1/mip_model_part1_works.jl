using JuMP, Gurobi, Combinatorics, Cbc
import XLSX


#### read data ####
xf = XLSX.readxlsx("../data/data1.xlsx")
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
#### ######

L = 10000 # large number

E = collect(powerset(collect(2:N), 2, N-1)) # for subtour 'E'limination constraints

########

model = Model();
set_optimizer(model, Gurobi.Optimizer);
#(13)
@variable(model, x[1:N, 1:N, 1:M], Bin)


######################## routing constraints ######################

# (2) each client served once by one provider
@constraint(model, served[j in 2:N], sum(x[i,j,k] for i in 1:N for k in 1:M) == 1)

# (3) route continuity
@constraint(model, continuity[p in 2:N, k in 1:M], sum(x[i,p,k] for i in 1:N) == sum(x[p,j,k] for j in 1:N) )

# (4) not all providers need to leave 14HS (and start working)
@constraint(model, leave_depot[k in 1:M], sum(x[1,j,k] for j in 2:N) <= 1)

# (5) not all providers need to return to 14HS (i.e. they didn't leave 14HS in the first place)
@constraint(model, return_depot[k in 1:M], sum(x[i,1,k] for i in 2:N) <= 1)

# (6) no self looping
@constraint(model, diag[k in 1:M], sum(x[i,i,k] for i in 1:N) == 0)

# (7) at least 1 provider must leave 14HS and start working to serve clients
@constraint(model, sum(x[1,j,k] for j in 2:N for k in 1:M) >= 1)

# (8) all providers must start their work at 14HS, if they do work
@constraint(model, large[k in 1:M], sum(x[i,j,k] for i in 2:N for j in 2:N) <= L*sum(x[1,j,k] for j in 2:N))

#(9) subtour elimination for each provider
for k in 1:M
    for e in 1:length(E)
        @constraint(model, sum(x[i,j,k] for i in E[e] for j in E[e]) <= length(E[e])-1)
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


# (1) minimise hiring cost to serve all clients
@objective(model, Min, sum(f[k]*x[1,j,k] for j in 1:N for k in 1:M))


optimize!(model)


(value.(x[:,:,1]))



for k in 1:M
    if sum(value.(x[1,:,k])) == 1
        println("vehicle $k provides service.")
        # come back hr
        for i in 2:N
            if value.(x[i,1,k]) == 1
                println("vehicle $k comes back to 14HS at $(t[i,1] + s[k,i] + d[i])hr. \n")
            end
        end
    end
end



path = [1 2 1]
#path = [1 7 1]
#path = [1 6 1]
#path = [1 3 4 5 1]

worked_hr = 0
#delivered  = 0
for i in 2:length(path)
    global worked_hr += t[path[i-1], path[i]] + d[path[i]]
    #global delivered += d[path[i]]
end
worked_hr
