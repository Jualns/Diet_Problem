import XLSX
using JuMP, Juniper, Ipopt
using LinearAlgebra
using HiGHS

if ~occursin("Dieta", pwd())
    try
        cd("C:\\Users\\joao.silva\\Desktop\\Github\\Diet_Problem")
    catch
        nothing
    end
end

#Utilizar com ativos fisicamente, objetivo: aumento de peso e massa magra.
#SUPERESTIMA O BASAL
function basal_Harris_Benedict(peso_kg, altura_cm, idade, sexo = 0)
    if sexo == 0 #homem
        return 66 + (13.8 * peso_kg) + (5 * altura_cm) - (6.8 * idade)
    else #mulher
        return 665 + (9.6 * peso_kg) + (1.9 * altura_cm) - (4.7 * idade)
    end
end

function basal_FAO_OMS(peso_kg, idade, sexo = 0)
    if sexo == 0 #homem
        if 10 ≤ idade < 18
            return (17.686 * peso_kg) + 658.2
        elseif 18 ≤ idade < 30
            return (15.057 * peso_kg) + 692.2
        elseif 30 ≤ idade < 60
            return (11.472 * peso_kg) + 873.1
        else
            return (11.711 * peso_kg) + 587.7
        end
    else #mulher
        if 10 ≤ idade < 18
            return (13.384 * peso_kg) + 692.6
        elseif 18 ≤ idade < 30
            return (14.818 * peso_kg) + 486.6
        elseif 30 ≤ idade < 60
            return (8.126 * peso_kg) + 845.6
        else
            return (9.082 * peso_kg) + 658.5
        end
    end
end

#objetivo de emagrecimento.
#MAIS PRECISA QUE Harris_Benedict
function basal_Mifflin_St_Jeor(peso_kg, altura_cm, idade, sexo = 0)
    if sexo == 0 #homem
        return (10 * peso_kg) + (6.25 * altura_cm) - (5 * idade) + 5
    else #mulher
        return (10 * peso_kg) + (6.25 * altura_cm) - (5 * idade) - 161
    end
end

#individuos ativos fisicamente e que possuem alto volume muscular e baixo percentual de gordura.
function basal_Cunningham_Tinsley(peso_kg, massa_magra; tipo = 1)
    if tipo == 1 #Cunningham (MLG)
        return (22 * massa_magra) + 500
    elseif tipo == 2 #Tinsley (MLG)
        return (25.9 * massa_magra) + 284
    else #Tinsley (P)
        return (24.8 * peso_kg) + 10
    end
end



kg = 87
age = 24
altura = 162
massa_magra = kg * (1 - (27.15 + 6) / 100) #22.15% de gordura, 6% de óssos e etc.
atividades = "Ativo"

set_basal = [
    basal_Harris_Benedict(kg, altura, age),
    basal_FAO_OMS(kg, age),
    basal_Mifflin_St_Jeor(kg, altura, age),
    basal_Cunningham_Tinsley(kg, massa_magra, tipo = 1),
    basal_Cunningham_Tinsley(kg, massa_magra, tipo = 2),
    basal_Cunningham_Tinsley(kg, massa_magra, tipo = 3),
]
println("Gasto Basal:")
println(set_basal)

basa = (set_basal[1] + set_basal[3]) / 2
println("João - ", basa)

gasto_total = 1.0
if atividades == "Sedentario"
    gasto_total = 1.2 * basa #1 a 1.39
elseif atividades == "Pouco ativo"
    gasto_total = 1.45 * basa #1.4 a 1.59
elseif atividades == "Ativo"
    gasto_total = 1.75 * basa #1.6 a 1.89
else #Muito Ativo
    gasto_total = 2.2 * basa #1.9 a 2.5
end
println("Gasto Total Calórico - ", gasto_total)

xf = XLSX.readxlsx("TACO_tabel.xlsx")
tamanho_final = string(xf["Taco"])[37:end-2] #tamanho inteiro [35:end-1]  da tabela, "A1:FX203"
sh = xf[string("Taco!A1:", tamanho_final)] #pego a tabela hidr do A3 até o tamanho_final

elementos = [3; 7; 26; 179; 222; 410; 456; 488; 567; 524; 260; 377; 131; 116; 213; 169; 54]
#peso = [5 2.5 2.5 5 1.5 2.5 2.5 1.5 1.5]
#3, 7, 26, 179, 222, 410, 456, 488, 567, 524, 260, 377
elementos .+= 1

# elementos em relação ao df e não a TACO
# 4 - banan 
# 5 - maçã
# 8 - ovo
# 15 - laranja
elementos_bin = [4; 5; 8; 15]

elementos_con = []
for k = 1:length(elementos)
    if k ∈ elementos_bin
        continue
    else
        push!(elementos_con, k)
    end
end

# peso por unidade do alimento acima
peso_unidade = [150; 100; 50; 150]

col = [2; 4; 5; 6; 7]

df = sh[elementos, col]
aux1 = replace.(df[1:end, 1:end-1], "Tr" => "0")
aux1 = replace.(aux1, "NA" => "0")
aux = parse.(Float64, replace.(aux1[1:end, 2:end], "," => "."))

df_ = [df[1:end, 1] aux df[1:end, end]]
df_bin = df[elementos_bin, 1:end]

df = df_[findall(x -> x ∉ elementos_bin, 1:length(elementos))]

prot_cal, gord_cal = kg .* [2.4 * 4 1 * 9]
carb_cal = gasto_total - prot_cal - gord_cal#basa - prot_cal - gord_cal

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

@objective(model, Max, sum(b)/alimentos + sum([(y_k + 1)/(y_k + 1) for y_k = y]))

@constraint(model, lim_comida_sup[i = 1:alimentos],
    x[i] ≤ lim_sup * b[i])

@constraint(model, lim_comida_inf[i = 1:alimentos],
    x[i] ≥ lim_inf * b[i])

@constraint(model, limites_carb, carb_cal*0.5 ≤ sum(x[i]*macros[elementos_con[i],1] for i = 1:alimentos)/100 + sum(y[j]*macros[elementos_bin[j],1]*peso_unidade[j] for j = 1:alimentos_bin)/100  ≤ carb_cal*1.5)

@constraint(model, limites_prot, prot_cal ≤ sum(x[i]*macros[elementos_con[i],2] for i = 1:alimentos)/100 + sum(y[j]*macros[elementos_bin[j],2]*peso_unidade[j] for j = 1:alimentos_bin)/100  ≤ prot_cal*2.0)

@constraint(model, limites_gord, gord_cal*0.5 ≤ sum(x[i]*macros[elementos_con[i],3] for i = 1:alimentos)/100 + sum(y[j]*macros[elementos_bin[j],3]*peso_unidade[j] for j = 1:alimentos_bin)/100  ≤ gord_cal)

@constraint(model, meta_calorica, gasto_total - 900 ≤ sum(sum(x[i].*macros[elementos_con[i],1:end]) for i = 1:alimentos)/100 + sum(sum(y[j].*macros[elementos_bin[j],1:end].*peso_unidade[j]) for j = 1:alimentos_bin)/100  ≤ gasto_total-600)

optimize!(model)

if typeof(objective_value(model)) == typeof(1.0)
    X = value.(x)
    B = value.(b)
    Y = value.(y)


    ids_cont = findall(x -> x == 1, B)
    ids_bin = findall(x -> x > 0, Y)

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
