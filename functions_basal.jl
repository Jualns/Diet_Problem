import Pkg
Pkg.add("XLSX")
Pkg.add("JuMP")
Pkg.add("Juniper")
Pkg.add("Ipopt")

import XLSX
using JuMP, Juniper, Ipopt
using LinearAlgebra

if ~occursin("Dieta", pwd())
    try
        cd("Desktop/Diet_Problem")
    catch
        nothing
    end
end

#Utilizar com ativos fisicamente, objetivo: aumento de peso e massa magra.
#SUPERESTIMA O BASAL
function basal_Harris_Benedict(peso_kg, altura_cm, idade, sexo=0)
    if sexo == 0 #homem
        return 66 + (13.8 * peso_kg) + (5 * altura_cm) - (6.8 * idade)
    else #mulher
        return 665 + (9.6 * peso_kg) + (1.9 * altura_cm) - (4.7 * idade)
    end
end

function basal_FAO_OMS(peso_kg, idade, sexo=0)
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
function basal_Mifflin_St_Jeor(peso_kg, altura_cm, idade, sexo=0)
    if sexo == 0 #homem
        return (10 * peso_kg) + (6.25 * altura_cm) - (5 * idade) + 5
    else #mulher
        return (10 * peso_kg) + (6.25 * altura_cm) - (5 * idade) - 161
    end
end

#individuos ativos fisicamente e que possuem alto volume muscular e baixo percentual de gordura.
function basal_Cunningham_Tinsley(peso_kg, massa_magra; tipo=1)
    if tipo == 1 #Cunningham (MLG)
        return (22 * massa_magra) + 500
    elseif tipo == 2 #Tinsley (MLG)
        return (25.9 * massa_magra) + 284
    else #Tinsley (P)
        return (24.8 * peso_kg) + 10
    end
end
