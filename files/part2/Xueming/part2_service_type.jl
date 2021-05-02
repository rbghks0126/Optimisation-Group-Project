using JuMP, Gurobi, Cbc
import XLSX

xf = XLSX.readxlsx("/Users/joker/Desktop//MAST90014/group assignment/data/data1_part2.xlsx")
l = xf["General!B1"] ## end time
N = xf["General!B3"] + 1  # number of locations
M = xf["General!B2"] ## number of providers
K = xf["General!B4"] ## number of service  types

# Clients
s = xf["Clients!A2:A$N"]
d = xf["Duration"][:]

## Providers
w = xf["Providers!B2:B$(M+1)"]
g = xf["Providers!A2:A$(K+1)"]
# clients who need certain type of service
A = xf["clients with service type"][:]

# providers who provide certain type of service
H = xf["provider with service type"][:]

s_test = ones(M, N)
for k in 1:M
    global s_test[k,:] = vcat([w[k]], s)
end
s = s_test

t = xf["Distances"][:]

model=Model(with_optimizer(Gurobi.Optimizer))
@variable(model, x[1:N, 1:N, 1:M, 1:K], Bin)
@variable(model, 1 <= u[1:N, 1:M] <= N-1)
@objective(model, Min, sum(g[k]*sum(x[1,j,v,k]*(sum(x[p,q,v,k]*(t[p,q] + d[p,k] + max(0, s[v,q] - s[v,p] - t[p,q] - d[p,k]) ) for p in skipmissing(A[k,:]) for q in skipmissing(A[k,:]))) for j in skipmissing(A[k,:]) for v in skipmissing(H[k,:])) for k in 1:K))


for k in 1:K
    for j in skipmissing(A[k,2:length(A[k,:])])
        @constraint(model, sum(x[i,j,v,k] for i in skipmissing(A[k,:]) for v in skipmissing(H[k,:])) == 1)
    end
end


for k in 1:K
    for p in skipmissing(A[k,2:length(A[k,:])])
        for v in skipmissing(H[k,:])
            @constraint(model, sum(x[i,p,v,k] for i in skipmissing(A[k,:])) == sum(x[p,j,v,k] for j in skipmissing(A[k,:])))
        end
    end
end


for k in 1:K
    for v in skipmissing(H[k,:])
        @constraint(model, sum(x[1,j,v,k] for j in skipmissing(A[k,2:length(A[k,:])])) <= 1)
    end
end

for k in 1:K
    @constraint(model, sum(x[1,j,v,k] for j in skipmissing(A[k,2:length(A[k,:])]) for v in skipmissing(H[k,:])) >= 1)
end


for k in 1:K
    for v in skipmissing(H[k,:])
        for i in skipmissing(A[k,2:length(A[k,:])])
            for j in skipmissing(A[k,2:length(A[k,:])])
                @constraint(model, u[i,v] - u[j,v] + (N-1) * x[i,j,v,k] <= (N-1) - 1 )
            end
        end
    end
end

for k in 1:K
    for j in skipmissing(A[k,2:length(A[k,:])])
        for v in skipmissing(H[k,:])
            @constraint(model, x[1,j,v,k]*(s[v,1] + t[1,j] + d[1,k]) <= s[v,j])
        end
    end
end

for k in 1:K
    for i in skipmissing(A[k,2:length(A[k,:])])
        for j in skipmissing(A[k,2:length(A[k,:])])
            for v in skipmissing(H[k,:])
                @constraint(model, x[i,j,v,k]*(s[v,i] + t[i,j] + d[i,k]) <= s[v,j])
            end
        end
    end
end


for k in 1:K
    for i in skipmissing(A[k,2:length(A[k,:])])
        for v in skipmissing(H[k,:])
            @constraint(model, x[i,1,v,k]*(s[v,i] + t[i,1] + d[i,k]) <= l)
        end
    end
end

optimize!(model)

for k in 1:K
    for v in 1:M
        if sum(value.(x[1,:,v,k])) == 1
            println("Provider $v provides service.")
            println("Provider $v costs $(g[k]) per hour.")
            # come back hr
            for i in 2:N
                if value.(x[i,1,v,k]) == 1
                    println("Provider $v comes back to 14HS at $(t[i,1] + s[v,i] + d[i,k])hr. \n")
                end
            end
        end
    end
end

function get_path(N, v, k)
    path = []
    for j in 2:N
        if value.(x[1,j,v,k]) == 1
            println("\nstart of path")
            println(1, " => ")
            path = vcat(path, [1])
            println(j, " => ")
            path = vcat(path, [j])
            i = j
            while value.(x[i,1,v,k]) == 0
                for m in 2:N
                    if value.(x[i,m,v,k]) == 1
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
        if value.(x[1,j,v,k]) == 1
            println("\nstart of path")
            println(0, " => ")
            println(j-1, " => ")
            i = j
            while value.(x[i,1,v,k]) == 0
                for m in 2:N
                    if value.(x[i,m,v,k]) == 1
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




function overview(path)
    println("$(s[v,1])hr: It is available at HS14 and leaves to client $(path[2]).")
    for i in 2:length(path)-1
        println("$(s[v,path[i-1]]+t[path[i-1], path[i]] + d[path[i-1],k])hr: It arrives at client $(path[i]).")
        if s[v,path[i-1]]+t[path[i-1], path[i]] + d[path[i-1],k] != s[v,path[i]]
            println(" It arrives early and waits until service start time.")
        end
        println("$(s[v,path[i]])hr: It serves for $(d[path[i],k]) hrs.")
        if path[i+1] == 1
            println("$(s[v,path[i]]+d[path[i],k])hr: It finishes the service at client $(path[i]) and leaves to HS14.")
        else
            println("$(s[v,path[i]]+d[path[i],k])hr: It finishes the service at client $(path[i]) and leaves to client $(path[i+1]).")
        end
    end
    println("$(s[v,path[length(path)-1]] + d[path[length(path)-1],k] + t[path[length(path)-1], 1])hr: It arrives back at HS14.\n")
end
v = 5
k = 3


path = get_path(N, v, k)

# print the overview of the path for provider k, where 'path' is found above using get_path(N,k)
overview(path)
