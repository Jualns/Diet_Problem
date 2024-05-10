using JuMP, Juniper, Ipopt
using LinearAlgebra
using HiGHS

include("get_macro.jl")
include("read_df_micro.jl")

df = sh[elementos, col]
aux1 = replace.(df[1:end, 1:end], "Tr" => "0")
aux1 = replace.(aux1, "NA" => "0")
aux = parse.(Float64, replace.(aux1[1:end, 2:end], "," => "."))

df_ = [df[1:end, 1] aux]
df_bin = df_[elementos_bin, 1:end]

dd = findall(x -> x ∉ elementos_bin, 1:length(elementos))
df = df_[dd, 1:end]

prot_cal, gord_cal = kg .* [2.4 * 4 1 * 9]
carb_cal = gasto_total - prot_cal - gord_cal #basa - prot_cal - gord_cal

carb_g = carb_cal / 4
prot_g = prot_cal / 4
gord_g = gord_cal / 9

alimentos = length(elementos) - length(elementos_bin) 
alimentos_bin = length(elementos_bin)

aux2 = ones(alimentos + alimentos_bin, 3)
aux2[1:end, 1:2] .= 4.0
aux2[1:end, 3] .= 9.0
macros = df_[1:end, 2:4] .* aux2

vet_cal = [carb_cal prot_cal gord_cal]
aux_ones = ones(3)

lim_sup = 2000
lim_inf = 100

optimizer = Juniper.Optimizer
nl_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 2)
mip_solver = optimizer_with_attributes(HiGHS.Optimizer)
model = Model(optimizer_with_attributes(optimizer, "nl_solver" => nl_solver,"mip_solver"=>mip_solver))
#model = Model(HiGHS.Optimizer)

cal_alimento = sum(macros, dims = 2)

@variable(model, lim_sup ≥ x[i = 1:alimentos] ≥ 0, start = 400)
@variable(model, 10 ≥ y[j = 1:alimentos_bin] ≥ 0, Int, start = 5)
@variable(model, b[i = 1:alimentos], Bin, start = true)

k = 10
kk = findfirst(t -> t == k,  col_micro) + 4

alpha = 1/df_micro["Alpha"][kk]

inf_ = df_micro["inf"][kk]

sup_ = df_micro["sup"][kk]
println(kk," ",alpha," ",inf_," ",sup_," ",df[1,kk])

function limites_micro(x)
    soma = 0.0
    
    for k_ = col_micro[1:17]
        local kk = findfirst(t -> t == k_,  col_micro)
        alpha = 1/df_micro["Alpha"][kk]
        inf_ = df_micro["inf"][kk]
        sup_ = df_micro["sup"][kk]

        kk += 4

        for i = 1:alimentos
            
            micro_inf = - alpha*max(0., inf_ - sum(x[i]*df[i,kk] for i = 1:alimentos)/100)
            micro_sup = - alpha*max(0., sum(x[i]*df[i,kk] for i = 1:alimentos)/100 - sup_) 
            
            soma += micro_sup + micro_inf

        end
    end
    return soma 
end

# alpha diferente por micro nutreiente (manualmente alterando)
# scatter dos pontos min, max e real da dieta por micronutreiente
# penalização na função objetivo
# adicionar mais alimentos na dieta
# adicionar o binário na penalização
@objective(model, Max, sum(b)/alimentos + limites_micro(x))

@constraint(model, lim_comida_sup[i = 1:alimentos],
    x[i] ≤ lim_sup * b[i])

@constraint(model, lim_comida_inf[i = 1:alimentos],
    x[i] ≥ lim_inf * b[i])

@constraint(model, limites_carb, carb_cal*0.5 ≤ sum(x[i]*macros[elementos_con[i],1] for i = 1:alimentos)/100 + sum(y[j]*macros[elementos_bin[j],1]*peso_unidade[j] for j = 1:alimentos_bin)/100  ≤ carb_cal*1.5)

@constraint(model, limites_prot, prot_cal ≤ sum(x[i]*macros[elementos_con[i],2] for i = 1:alimentos)/100 + sum(y[j]*macros[elementos_bin[j],2]*peso_unidade[j] for j = 1:alimentos_bin)/100  ≤ prot_cal*2.0)

@constraint(model, limites_gord, gord_cal*0.5 ≤ sum(x[i]*macros[elementos_con[i],3] for i = 1:alimentos)/100 + sum(y[j]*macros[elementos_bin[j],3]*peso_unidade[j] for j = 1:alimentos_bin)/100  ≤ gord_cal)

# testar adicionar só uma restrição de micronutreiente por vez (para encontrar qual micro está dando erro)
# 11 deu mais comida
# 1:2 foi
# 4:10 foi
# 12:17 foi
# União de todas boas deu ruim
#for k = col_micro[1:17]
#    local kk = findfirst(x -> x == k,  col_micro) + 4
    #@constraint(model, limits_micro[k][1] ≤ sum(x[i]*df[i,kk] for i = 1:alimentos)/100 + sum(y[j]*df_bin[j,kk]*peso_unidade[j] for j = 1:alimentos_bin)/100 ≤ limits_micro[k][2])
#end

@constraint(model, meta_calorica, gasto_total - 900 ≤ sum(sum(x[i].*macros[elementos_con[i],1:end]) for i = 1:alimentos)/100 + sum(sum(y[j].*macros[elementos_bin[j],1:end].*peso_unidade[j]) for j = 1:alimentos_bin)/100  ≤ gasto_total-600)

optimize!(model)

if typeof(objective_value(model)) == typeof(1.0)
    X = value.(x)
    B = value.(b)
    Y = value.(y)


    ids_cont = findall(x -> abs(x - 1) < 0.2, B)
    ids_bin = findall(x -> x > 0.2, Y)

    println(solution_summary(model; verbose = true))
    
    for k = ids_cont
        println("Preciso comer ", round(X[k], digits = 2), " gramas de ", df_[elementos_con[k], 1])
    end

    for k = ids_bin
        println("Preciso comer ",  Y[k], " unidades de ", df_[elementos_bin[k], 1])
    end

    println("Totalizando ", round(sum(X) + Y'peso_unidade, digits = 2), " de gramas por dia!")
    println("Total de calorias consumidas com essa dieta: ", round(value(meta_calorica), digits = 2))
end

# d[findall(x -> x == id_ref, d[:,1]), :]
