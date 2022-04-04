import XLSX
using JuMP, Juniper, Ipopt
using LinearAlgebra

optimizer = Juniper.Optimizer
nl_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
model = Model(optimizer_with_attributes(optimizer, "nl_solver" => nl_solver))#,"mip_solver"=>mip_solver))


lim_sup = 10
@variable(model, lim_sup ≥ quantidade_alimento[i = 1:alimentos] ≥ 0)
@variable(model, quantidade[i = 1:alimentos], Bin)

#@objective(model, Max, sum(quantidade)/basa + sum(quantidade_alimento[i] for i = 1:alimentos)/10) #/10 retorna a quantidade de alimentos em kg
@objective(model, Max, sum(quantidade_alimento + quantidade)/alimentos)
#@constraint(model, meta_calorica,  quantidade_alimento[i]*sum(macros[i,1:3]) - basa ≤ 1e-2)

@constraint(model, limitante_comida[i = 1:alimentos], quantidade_alimento[i] ≤ quantidade[i]*lim_sup)

@constraint(model, limitante_comida_inf[i = 1:alimentos], quantidade_alimento[i] ≥ quantidade[i]*1e-1)

@constraint(model, meta_carb, -1e-4 ≤ sum(quantidade_alimento[i]*macros[i,1] for i = 1:alimentos) - carb_cal  ≤ 1e-4)

@constraint(model, meta_prot, -1e-4 ≤ sum(quantidade_alimento[i]*macros[i,2] for i = 1:alimentos) - prot_cal ≤ 1e-4)

@constraint(model, meta_gord, -1e-4 ≤ sum(quantidade_alimento[i]*macros[i,3] for i = 1:alimentos) - gord_cal ≤ 1e-4)

optimize!(model)

if typeof(objective_value(model)) == typeof(1.)
    g = value.(quantidade_alimento)
    q = value.(quantidade)

    posic = findall(x -> x > 1e-5, g)

    d = [df[posic,1] g[posic]]
end
