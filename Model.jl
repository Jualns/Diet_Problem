import XLSX
using JuMP, Juniper, Ipopt
using LinearAlgebra

if ~occursin("Dieta", pwd())
    try
        cd("Desktop/Dieta")
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



kg = 64
age = 21
altura = 162
massa_magra = kg * (1 - (22.15 + 6) / 100) #22.15% de gordura, 6% de óssos e etc.
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
tamanho_final = string(xf["Tabela1"])[40:end-1] #tamanho inteiro [35:end-1]  da tabela, "A1:FX203"
sh = xf[string("Tabela1!A1:", tamanho_final)] #pego a tabela hidr do A3 até o tamanho_final

elementos = [3; 7; 26; 179; 222; 410; 456; 488; 567; 524; 260; 377; 131; 116; 213; 169; 54]
#peso = [5 2.5 2.5 5 1.5 2.5 2.5 1.5 1.5]
#3, 7, 26, 179, 222, 410, 456, 488, 567, 524, 260, 377
elementos .+= 1

col = [2; 4; 5; 6; 7]

df = sh[elementos, col]
aux1 = replace.(df[1:end, 1:end-1], "Tr" => "0")
aux1 = replace.(aux1, "NA" => "0")
aux = parse.(Float64, replace.(aux1[1:end, 2:end], "," => "."))

df = [df[1:end, 1] aux df[1:end, end]]

prot_cal, gord_cal = kg .* [2.4 * 4 1 * 9]
carb_cal = gasto_total - prot_cal - gord_cal#basa - prot_cal - gord_cal

carb_g = carb_cal / 4
prot_g = prot_cal / 4
gord_g = gord_cal / 9

alimentos = length(elementos)
aux2 = ones(alimentos, 3)
aux2[1:end, 1:2] .= 4.0
aux2[1:end, 3] .= 9.0
macros = df[1:end, 2:4] .* aux2

vet_cal = [carb_cal prot_cal gord_cal]
aux_ones = ones(3)

optimizer = Juniper.Optimizer
nl_solver = optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0)
model = Model(optimizer_with_attributes(optimizer, "nl_solver" => nl_solver))#,"mip_solver"=>mip_solver))


lim_sup = 800
refeicoes = 5
tipo_refeicao = ['C', 'P']
df_ref = ones(alimentos, length(tipo_refeicao))
df_ref[1,1] = 0
df_ref[6,1] = 0
df_ref[9,1] = 0
df_ref[11,1] = 0
df_ref[12,1] = 0
df_ref[10,1] = 0
df_ref[14,1] = 0
df_ref[16,1] = 0

df_ref[2,2] = 0
df_ref[3,2] = 0
df_ref[4,2] = 0
df_ref[5,2] = 0
df_ref[7,2] = 0
df_ref[8,2] = 0
df_ref[17,2] = 0


ordem_ref = [1, 2, 1 ,2, 1]
ref = ['C', 'P']
cal_alimento = sum(macros, dims = 2)
α = 1e-4
μ = 1e-3

@variable(model, lim_sup ≥ quantidade_alimento[i = 1:alimentos, j = 1:refeicoes] ≥ 0, start = lim_sup)
@variable(model, quantidade[i = 1:alimentos, j = 1:refeicoes], Bin, start = true)
#@objective(model, Max, sum(quantidade)/basa + sum(quantidade_alimento[i] for i = 1:alimentos)/10) #/10 retorna a quantidade de alimentos em kg
#@objective(model, Max, sum(-quantidade_alimento/100 + 1e-5 * quantidade) / alimentos) #FUNCIONA
@objective(model, Max, -sum(quantidade_alimento)/(lim_sup*alimentos) + μ*sum(quantidade.^2))
#@constraint(model, meta_calorica,  quantidade_alimento[i]*sum(macros[i,1:3]) - basa ≤ 1e-2)

@constraint( model, limitante_comida[i = 1:alimentos, j = 1:refeicoes],
    quantidade_alimento[i,j]/100 ≤ quantidade[i,j] * lim_sup * df_ref[i,ordem_ref[j]])

@constraint( model, limitante_comida_inf[i = 1:alimentos, j = 1:refeicoes],
    quantidade_alimento[i,j]/100 ≥ quantidade[i,j] * df_ref[i,ordem_ref[j]])

@constraint(  model,  meta_cal_ref[j = 1:refeicoes],
    -α ≤  sum(quantidade_alimento[i, j]*cal_alimento[i] for i = 1:alimentos)/100 - gasto_total/refeicoes ≤  α)

@constraint(model, meta_carb, -α ≤ sum(quantidade_alimento[i,j]*macros[i,1] for i = 1:alimentos, j = 1:refeicoes)/100 - carb_cal ≤ α)

@constraint(model, meta_prot, -α ≤ sum(quantidade_alimento[i,j]*macros[i,2] for i = 1:alimentos, j = 1:refeicoes)/100 - prot_cal ≤ α)

@constraint(model, meta_gord, -α ≤ sum(quantidade_alimento[i,j]*macros[i,3] for i = 1:alimentos, j = 1:refeicoes)/100 - gord_cal ≤ α)


optimize!(model)

if typeof(objective_value(model)) == typeof(1.0)
    g = value.(quantidade_alimento)
    q = value.(quantidade)

    posic = findall(x -> x > α, g)
    I = [k[1] for k = posic]
    J = [k[2] for k = posic]
    d = [J ref[ordem_ref[J]] df[I, 1] g[posic]]
    gramas = d[:,end]
end

# d[findall(x -> x == id_ref, d[:,1]), :]
