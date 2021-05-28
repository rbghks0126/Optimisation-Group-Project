using JuMP, Gurobi, Combinatorics, Cbc
import XLSX


#### read data ####
xf = XLSX.readxlsx("../data/data2_simplified2.xlsx")
l = 8     # work day duration
N = xf["General!B3"] + 1  # number of clients + 1
M = xf["General!B2"]  # number of providers
# + 1 is for including the headquarter (HS14)

# Clients
s = xf["Clients!A2:A$N"]   # client service start times
d = vcat([0], xf["Clients!B2:B$N"])   # durations for clients, set d[1] = 0 for HS14


# Providers
w = xf["Providers!B2:B$(M+1)"]  # start time of providers
f = xf["Providers!A2:A$(M+1)"]  # hiring cost of providers

t = xf["Distances"][:]  # 2-d array of travel times


s_test = ones(M, N)

for k in 1:M
    global s_test[k,:] = vcat([w[k]], s)
end
s = s_test

model = Model();
# Gurobi.setparam!(backend(model).optimizer.model.inner, "TimeLimit", 100.0)
set_optimizer(model, Gurobi.Optimizer);
set_time_limit_sec(model, 100.0);

#(13)
@variable(model, x[1:N, 1:N, 1:M], Bin)
@variable(model, 1 <= u[1:N, 1:M] <= N-1)
@variable(model, tl[1:N, 1:M] >= 0, Int)#Tardiness hours
@variable(model, te[1:N, 1:M] >= 0, Int)# early hours
@variable(model, td[1:N, 1:N, 1:M] >= 0, Int)# actual depature time
P = 30 # later arrival penalty cost = 30/hour
######################## routing constraints ######################

# #
# each client served once by one provider
@constraint(model, served[j in 2:N], sum(x[i,j,k] for  k in 1:M, i in 1:N if j != i) == 1)


# route continuity
# @constraint(model, continuity[p in 2:N, k in 1:M], sum(x[i,p,k] for i in 1:N) == sum(x[p,j,k] for j in 1:N) )
@constraint(model, continuity[j in 1:N, k in 1:M],(sum(x[i,j,k] for i in 1:N)-sum(x[j,i,k] for i in 1:N))==0 )

#  all providers only provide service once/ each vehicle is used at most once
@constraint(model, leave_depot[k in 1:M], sum(x[1,j,k] for j in 2:N) <= 1)


# subtour elimination for each provider
for k in 1:M
    for i in 2:N
        for j in 2:N
            @constraint(model, u[i,k] - u[j,k] + (N-1) * x[i,j,k] <= (N-1) - 1 )
        end
    end
end


#Either arrive early, arrive on time or late
@constraint(model, oneinthree[i in 1:N, j in 1:N, k in 1:M], tl[j,k]*te[j,k] == 0 )
# service provider depoart from depot if they work, and they depart as soon as they are available.
@constraint(model, work_when_avai[j in 1:N, k in 1:M], td[1,j,k] == x[1,j,k]*s[k,1])
#define the actual depature time
@constraint(model, actual_dep[i in 1:N, j in 1:N, k in 1:M], x[i,j,k]*(s[k,i]+tl[i,k]+d[i])==td[i,j,k])
# come back to 14HS by hour l
@constraint(model, back_depot[i in 1:N, k in 1:M], x[i,1,k]*(td[i,1,k]+t[i,1]) <= l)
# define the next actual arrival time
@constraint(model, late[i in 1:N, j in 2:N, k in 1:M], x[i,j,k]*(td[i,j,k]+t[i,k])==x[i,j,k]*(s[k,i]+tl[j,k]-te[j,k]))
######################## end time constraints ######################

# @objective(model, Min,sum(f[k]*x[1,j,k] for j in 1:N for k in 1:M))
# @objective(model, Min, sum(f[k]*x[i,1,k]*(td[i,1,k]+t[i,1]-s[k,1]) for i in 1:N for k in 1:M)+sum(tl[j,k]*P*sum(x[i,j,k] for i in N) for j in 1:N for k in 1:M))
@objective(model, Min,sum(x[1,j,k]*f[k]*(sum(x[p,q,k]*(t[p,q] + d[p] + max(0, s[k,q] - s[k,p] - t[p,q] - d[p])) for p in 1:N for q in 1:N)) for j in 2:N for k in 1:M) +sum(tl[j,k]*P*sum(x[i,j,k] for i in N) for j in N for k in M))
optimize!(model)


# @show (value.(x[:,:,1]))


for k in 1:M
    length = 0
    if sum(value.(x[1,:,k])) >= 1
        println("Provider $k provides service ")
        # come back hr
        for i in 1:N
            if value.(x[i,1,k]) >= 1
                println("Provider $k comes back to 14HS at ",
                value(sum(x[i,j,k]*( t[i,j] + d[j]) for i in 1:N, j in 1:N)),"hr.")
                # break
            end
        end
        for i in 1:N
            for j in 1:N
                if value.(x[i,j,k])>=1
                    println(i,"-",j)
                    length = length + t[i,j]
                end
            end
        end
    end
    println("travel length:", length)
    println()
end

for k in 1:M
    for j in 1:N
        if value.(tl[j,k])>0
            println("There is penalty cost for vehicle $k at customer $j with tardiness hour ", value.(tl[j,k]))
        end
    end
end
