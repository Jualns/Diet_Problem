using CSV
using DataFrames

function get_valor(micro, coluna, df_micro)
    return filter(row -> row.Nutriente == micro, df_micro)[!, coluna][1]
end

base_path = pwd()

# Substitua "arquivo.csv" pelo caminho do seu arquivo CSV
arquivo = "\\docs\\micro_lims.csv"

path = string(base_path, arquivo)

# Abrindo o arquivo CSV
df_micro = CSV.read(path, DataFrame)