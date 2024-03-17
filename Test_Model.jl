kg = 64
age = 21
altura = 162
massa_magra = kg*(1 - (22.15 + 6)/100) #22.15% de gordura, 6% de óssos e etc.
atividades = "Ativo"

set_basal = [basal_Harris_Benedict(kg, altura, age),
            basal_FAO_OMS(kg, age),
            basal_Mifflin_St_Jeor(kg, altura, age),
            basal_Cunningham_Tinsley(kg, massa_magra, tipo = 1),
            basal_Cunningham_Tinsley(kg, massa_magra, tipo = 2),
            basal_Cunningham_Tinsley(kg, massa_magra, tipo = 3)]
println("Gasto Basal:")
println(set_basal)

basa = (set_basal[1] + set_basal[3])/2
println("João - ", basa)

gasto_total = 1.
if atividades == "Sedentario"
    gasto_total = 1.2*basa #1 a 1.39
elseif atividades == "Pouco ativo"
    gasto_total = 1.45*basa #1.4 a 1.59
elseif atividades == "Ativo"
    gasto_total = 1.75*basa #1.6 a 1.89
else #Muito Ativo
    gasto_total = 2.2*basa #1.9 a 2.5
end
println("Gasto Total Calórico - ", gasto_total)

xf = XLSX.readxlsx("TACO_tabel.xlsx")
tamanho_final = string(xf["Tabela1"])[40:end-1] #tamanho inteiro [35:end-1]  da tabela, "A1:FX203"
sh = xf[string("Tabela1!A1:",tamanho_final)] #pego a tabela hidr do A3 até o tamanho_final

elementos = [3; 179; 222; 410; 456; 488; 567; 524; 260]
#peso = [5 2.5 2.5 5 1.5 2.5 2.5 1.5 1.5]
elementos .+= 1

col = [2; 4; 5; 6; 7]

df = sh[elementos,col]
aux1 = replace.(df[1:end, 1:end-1], "Tr" => "0")
aux1 = replace.(aux1, "NA" => "0")
aux = parse.(Float64,replace.(aux1[1:end, 2:end], "," => "."))

df = [df[1:end, 1] aux df[1:end, end]]

prot_cal, gord_cal = kg.*[2.0*4 0.5*9]
carb_cal = basa - prot_cal - gord_cal

carb_g = carb_cal/4
prot_g = prot_cal/4
gord_g = gord_cal/9

alimentos = length(elementos)
aux2 = ones(alimentos,3)
aux2[1:end, 1:2] .= 4.
aux2[1:end, 3] .= 9.
macros = df[1:end, 2:4].*aux2

vet_cal = [carb_cal prot_cal gord_cal]
aux_ones = ones(3)
