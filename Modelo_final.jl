using JuMP, Juniper, Ipopt
using LinearAlgebra
using HiGHS

include("get_macro.jl")
include("read_df_micro.jl")
include("read_base_csv.jl")
include("read_json.jl")

#df_micro
#csv_gramas
#csv_inteiro

INF = df_micro[!, "inf"]
SUP = df_micro[!, "sup"]
ALPHA = df_micro[!, "Alpha"]

macros_g = Array(csv_gramas[!,["Carboidrato (g)", "Proteína (g)","Lipídeos (g)"]])
macros_i = Array(csv_inteiros[!,["Carboidrato (g)", "Proteína (g)","Lipídeos (g)"]])
micros_g = Array(csv_gramas[!,["Colesterol (mg)", "Fibra Alimentar (g)", "Cálcio (mg)", "Magnésio (mg)", "Manganês (mg)", "Fósforo (mg)", "Ferro (mg)", "Sódio (mg)", "Potássio (mg)", "Cobre (mg)", "Zinco (mg)", "Retinol (μg)", "Tiamina (mg)", "Riboflavina (mg)", "Piridoxina (mg)", "Niacina (mg)", "Vitamina C (mg)"]])
micros_i = Array(csv_inteiros[!,["Colesterol (mg)", "Fibra Alimentar (g)", "Cálcio (mg)", "Magnésio (mg)", "Manganês (mg)", "Fósforo (mg)", "Ferro (mg)", "Sódio (mg)", "Potássio (mg)", "Cobre (mg)", "Zinco (mg)", "Retinol (μg)", "Tiamina (mg)", "Riboflavina (mg)", "Piridoxina (mg)", "Niacina (mg)", "Vitamina C (mg)"]])

prot_cal, gord_cal = kg .* [2.4 * 4 1 * 9]
carb_cal = gasto_total - prot_cal - gord_cal #basa - prot_cal - gord_cal

carb_g = carb_cal / 4
prot_g = prot_cal / 4
gord_g = gord_cal / 9

cal_macro = [4.0; 4.0; 9.0]

# quantidade de alimentos das gramas
alimentos = size(csv_gramas)[1]

# quantidade de alimentos inteiros
alimentos_bin = size(csv_inteiros)[1]

# quantidade de micronutrientes
quantidade_micros = size(df_micro)[1]

# limites de gramas para cada alimento
lim_sup = 2000
lim_inf = 100.0


optimizer = Juniper.Optimizer
nl_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 2)
mip_solver = optimizer_with_attributes(HiGHS.Optimizer)
model = Model(optimizer_with_attributes(optimizer, "nl_solver" => nl_solver,"mip_solver"=>mip_solver))

@variable(model, lim_sup ≥ x[i = 1:alimentos] ≥ 0, start = 400)
@variable(model, 3 ≥ y[j = 1:alimentos_bin] ≥ 0, Int, start = 2)
@variable(model, b[i = 1:alimentos], Bin, start = true)

f(x) = (sqrt(x^2 + 1e-8) + x)/2

function penalizacao(x, y, nome_micro)
    id_micro = findfirst(n -> n == nome_micro, df_micro.Nutriente)

    quant_micro_x = sum(x[i]*csv_gramas[i,nome_micro] for i = 1:alimentos)
    quant_micro_y = sum(y[j]*csv_gramas[j,nome_micro] for j = 1:alimentos_bin)

    quant_micro = quant_micro_x + quant_micro_y
    
    α = 1/ALPHA[id_micro]

    #micro_inf = - α*max(0., INF[id_micro] - quant_micro)
    #micro_sup = - α*max(0., quant_micro - SUP[id_micro]) 
    
    micro_inf = - α*f(INF[id_micro] - quant_micro)
    if abs(SUP[id_micro] - 9999.0) > 1e-2
        micro_sup = - α*f(quant_micro - SUP[id_micro])
        return  micro_sup + micro_inf
    end

    return micro_inf

end




id_micro = 2

g(x) = penalizacao(x, y, "Colesterol (mg)") + penalizacao(x, y, "Fibra Alimentar (g)") + penalizacao(x, y, "Cálcio (mg)") + penalizacao(x, y, "Magnésio (mg)") + penalizacao(x, y, "Manganês (mg)") + penalizacao(x, y, "Fósforo (mg)") + penalizacao(x, y, "Ferro (mg)") + penalizacao(x, y, "Sódio (mg)") + penalizacao(x, y, "Potássio (mg)") + penalizacao(x, y, "Cobre (mg)") + penalizacao(x, y, "Zinco (mg)") + penalizacao(x, y, "Retinol (μg)") + penalizacao(x, y, "Tiamina (mg)") + penalizacao(x, y, "Riboflavina (mg)") + penalizacao(x, y, "Piridoxina (mg)") + penalizacao(x, y, "Niacina (mg)") + penalizacao(x, y, "Vitamina C (mg)")

@objective(model, Max, sum(b)/alimentos + sum(y[j]/(y[j]+1e-5) for j = 1:alimentos_bin)/alimentos_bin + g(x))

#@objective(model, Max, sum(b)/alimentos + sum(y[j]/(y[j]+1e-5) for j = 1:alimentos_bin)/alimentos_bin - sum(β[n] for n = 1:quantidade_micros))

@constraint(model, lim_comida_sup[i = 1:alimentos],
    x[i] ≤ lim_sup * b[i])

@constraint(model, lim_comida_inf[i = 1:alimentos],
    x[i] ≥ lim_inf * b[i])

@constraint(model, limites_carb, carb_g*0.5 ≤ sum(x[i]*macros_g[i, 1] for i = 1:alimentos) + sum(y[j]*macros_i[j, 1] for j = 1:alimentos_bin)  ≤ carb_g*1.5)

@constraint(model, limites_prot, prot_g ≤ sum(x[i]*macros_g[i,2] for i = 1:alimentos) + sum(y[j]*macros_i[j,2] for j = 1:alimentos_bin)  ≤ prot_g*2.0)

@constraint(model, limites_gord, gord_g*0.5 ≤ sum(x[i]*macros_g[i,3] for i = 1:alimentos) + sum(y[j]*macros_i[j,3] for j = 1:alimentos_bin)  ≤ gord_g)

@constraint(model, 
    meta_calorica, 
        gasto_total - 500 ≤ 
        sum(sum(x[i]*(macros_g[i,:]'cal_macro) for i = 1:alimentos) + sum(sum(y[j]*(macros_i[j,:]'cal_macro) for j = 1:alimentos_bin))) 
        ≤ gasto_total
)
        
optimize!(model)

if typeof(objective_value(model)) == typeof(1.0)
    X = value.(x)
    B = value.(b)
    Y = value.(y)


    ids_cont = findall(x -> abs(x - 1) < 0.2, B)
    ids_bin = findall(x -> x > 0.2, Y)

    println(solution_summary(model; verbose = true))
    

    for k = ids_cont
        round_x = round(X[k], digits = 2)
        println("Preciso comer ", round_x, " gramas de ", csv_gramas.Nome[k])
    end

    
    for k = ids_bin
        round_y = round(Y[k], digits = 2)
        round_gramas_y = round(Y[k]*json["gramas_por_unidade"][k], digits = 2)
        println("Preciso comer ", round_y , " unidades (", round_gramas_y, " gramas) de ", csv_inteiros.Nome[k])
    end

    println("Totalizando ", round(sum(X) + Y'json["gramas_por_unidade"], digits = 2), " de gramas e ", round(sum(Y), digits = 2), " unidades por dia!")
    println("Total de calorias consumidas com essa dieta: ", round(value(meta_calorica), digits = 2))
end

for micro_ in df_micro.Nutriente
    println("Penalizacao ", micro_, " ", penalizacao(X, micro_))
end