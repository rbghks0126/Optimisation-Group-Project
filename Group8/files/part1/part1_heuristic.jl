import JuMP, Cbc, XLSX
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


#@btime heuristics_result(provider_sorted, client_sorted, copy(w), s_times, t, d)






past_client



num_served
length(past_client)
is_feasible(past_client)
compute_cost(num_served)

# k is the provider# you want to get the path for
#k=19.0
function get_path(num_served, past_client, k)
    path = get_heuristics_path(num_served, past_client, k)
    path += convert(Array{Int,1}, ones(length(get_heuristics_path(num_served, past_client, k))))
    return (path)
end

#dict1 = Dict(19 => [1,2,4,1])
#dict1[19]

function get_workers(num_served)
    workers = zeros(0)
    for i in 1:size(num_served)[1]
        if num_served[i,:][2] != 0
            append!(workers, num_served[i,:][1])
        end
    end
    return workers
end


get_workers(num_served)
get_path(num_served, past_client, get_workers(num_served)[1])
dict = Dict(i => get_path(num_served, past_client, get_workers(num_served)[i]) for i in 1:length(get_workers(num_served)))
dict
