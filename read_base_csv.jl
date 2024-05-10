using CSV
using DataFrames

base_path = pwd()

# Substitua "arquivo.csv" pelo caminho do seu arquivo CSV
arquivo = "\\infos\\base_csv.csv"

path = string(base_path, arquivo)

# Abrindo o arquivo CSV
base_csv = CSV.read(path, DataFrame)

csv_gramas = filter(row -> row.Tipo == "gramas", base_csv)
csv_inteiros = filter(row -> row.Tipo == "inteiros", base_csv)