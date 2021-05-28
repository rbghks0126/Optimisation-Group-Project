using JuMP, Gurobi, Cbc
import XLSX
using BenchmarkTools

# make sure u set the working directory to current files folder
data = XLSX.readxlsx("../data/part1/data_numP100_numC25_10_05_23_17.xlsx")

#General
General = data["General"];
l = General["B1"]
num_providers = General["B2"]
num_clients = General["B3"]

#Providers
Providers = data["Providers"];
provCostString  = string("A2:A", num_providers+1)
provStartString = string("B2:B", num_providers+1)
f = Providers[provCostString]
w = Providers[provStartString]

#Providers
Clients = data["Clients"];
clientStartString  = string("A2:A", num_clients+1)
clientDurationString  = string("B2:B", num_clients+1)
s_times = Clients[clientStartString]
d = Clients[clientDurationString]

#Distances
Distances = data["Distances"];
t = Distances[Distances.dimension]

# need to convert to floats to use 'sortperm' below
w = convert(Array{Float64,1}, w[:,1])
s_times = convert(Array{Float64,1}, s_times[:,1])
d = convert(Array{Float64,1}, d[:,1])
f = convert(Array{Float64,1}, f[:,1])


client_sorted = sortperm(s_times)  # client start times sorted (in index)
arr = [[f[i], w[i]] for i in 1:length(w)]
provider_sorted = sortperm(f) # providers cost and start time sorted


# heuristic function that computes feasible routes (but likely not optimal, i.e. minimum cost)
function heuristics_result(provider_sorted, client_sorted, w, s_times, t, d)
    past_client = zeros(0)
    num_served = zeros(num_providers, 2)
    num_served[:,1] = provider_sorted

    for m in provider_sorted  # for each index in sorted provider, and then for each client
        current_location = 1  # 1 is at depot(14HS) currently
        for n in client_sorted
            # only proceed if this client has not been assigned to a provider yet.
            if n ∉ past_client
                currentTime_provider = w[m]
                currentTime_client = s_times[n]
                travelTime = t[current_location, n+1] # n+1 is nth client in the t matrix

                #time to travel from provider's current location to the client plus the time when the provider is free.
                time_to_arrive = travelTime + currentTime_provider

                #Time to serve client "n".
                duration = d[n]
                #Time finished serving client "n".
                finish_time = currentTime_client + duration

                #Ensure the provider can arrive in time (at or earlier than service start times)
                # Must return back the origin (14HS) by hour l at latest.
                if currentTime_client >= time_to_arrive && finish_time <= l - t[n+1, 1]
                        println("Provider: ", m, " is assigned to client: ", n)
                        num_served[findfirst(isequal(m), num_served[:,1]), 2] += 1
                        w[m] = finish_time # update the time of provider m
                        current_location = n+1  # n+1 is nth client in the t-matrix
                        append!(past_client, n) # record service provided for client n
                end
            end
        end
        # end the algorithm if we have served all clients. so O(N*<M)?
        if length(past_client) == length(client_sorted)
            break
        end
    end
    println("\n")
    return convert(Array{Int,2}, num_served), convert(Array{Int,1}, past_client)
end

function compute_cost(num_served)
    cost = 0
    for i in 1:length(num_served[:,2])
        if num_served[:,2][i] > 0
            cost += f[num_served[:,1][i]]
        end
    end
    return cost
end

function is_feasible(past_client)
    return length(past_client) == length(client_sorted)
end

function get_heuristics_path(num_served, past_client, k)
    path = zeros(1)
    k_ind = findfirst(isequal(k), num_served[:,1])
    if k_ind == 1
        for i in 1:num_served[1,2]
            append!(path, past_client[i])
        end
    end
    if k_ind != 1
        start_ind = sum(num_served[1:k_ind-1,2]) + 1
        for i in start_ind:start_ind+num_served[k_ind,2]-1
            append!(path, past_client[i])
        end
    end
    return convert(Array{Int,1}, append!(path, zeros(1))) # convert to integer array
end


num_served, past_client = heuristics_result(provider_sorted, client_sorted, copy(w), s_times, t, d)
num_served
println(client_sorted)

#@btime heuristics_result(provider_sorted, client_sorted, copy(w), s_times, t, d)


length(past_client)
is_feasible(past_client)
compute_cost(num_served)

function get_path(num_served, past_client, k)
    path = get_heuristics_path(num_served, past_client, k)
    path += convert(Array{Int,1}, ones(length(get_heuristics_path(num_served, past_client, k))))
    return (path)
end

function get_workers(num_served)
    workers = zeros(0)
    for i in 1:size(num_served)[1]
        if num_served[i,:][2] != 0
            append!(workers, num_served[i,:][1])
        end
    end
    return workers
end


path_dict = Dict(trunc(Int, get_workers(num_served)[i]) => get_path(num_served, past_client, get_workers(num_served)[i]) for i in 1:length(get_workers(num_served)))


################### MIP ######################################
################### MIP ######################################
################### MIP ######################################
################### MIP ######################################
################### MIP ######################################
using JuMP, Gurobi, Cbc
import XLSX
using BenchmarkTools


#### read data ####
#xf = XLSX.readxlsx("../data/part1/data_numP10_numC10_09_05_13_29.xlsx")
xf = XLSX.readxlsx("../data/part1/data_numP200_numC150_11_05_34_00.xlsx")

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
set_time_limit_sec(model, 300.0);


#(13)
@variable(model, x[1:N, 1:N, 1:M], Bin)

#################### setting start values from heursitic solution ###########

for i in 1:N
    for j in 1:N
        for k in 1:M
            set_start_value(x[i,j,k], 0)
        end
    end
end

for key in keys(path_dict)
    path = path_dict[key]
    for i in 1:length(path)-1
        set_start_value(x[path[i], path[i+1], key], 1)
    end
end


################################################################################


# subtour constraint variables using u
@variable(model, 1 <= u[1:N, 1:M] <= N-1)

######################## routing constraints ######################

# (2) each client served once by one provider
@constraint(model, served[j in 2:N], sum(x[i,j,k] for i in 1:N for k in 1:M) == 1)

# (3) route continuity
@constraint(model, continuity[p in 2:N, k in 1:M], sum(x[i,p,k] for i in 1:N) == sum(x[p,j,k] for j in 1:N) )

# (4) not all providers need to leave 14HS (and start working)
@constraint(model, leave_depot[k in 1:M], sum(x[1,j,k] for j in 2:N) <= 1)

# (7) at least 1 provider must leave 14HS and start working to serve clients
@constraint(model, sum(x[1,j,k] for j in 2:N for k in 1:M) >= 1)


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
#@objective(model, Min, sum(x[1,j,k]*f[k]*(sum(x[p,q,k]*(t[p,q] + d[p] + max(0, s[k,q] - s[k,p] - t[p,q] - d[p]) ) for p in 1:N for q in 1:N)) for j in 2:N for k in 1:M))

# original non-hourly objective for part 1
@objective(model, Min, sum(f[k]*x[1,j,k] for j in 1:N for k in 1:M))

optimize!(model)

@btime optimize!(model)



x[1,:,1]
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
worked_hr = s[k,path[length(path)-1]] + d[path[length(path)-1]] + t[path[length(path)-1], 1] - s[k,1]
println("Provider $k worked for $worked_hr hours.")
