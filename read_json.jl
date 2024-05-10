using JSON

# Caminho para o arquivo JSON
base_path = pwd()

# Substitua "arquivo.csv" pelo caminho do seu arquivo CSV
arquivo = "\\infos\\alimentos_selecionados.json"

path = string(base_path, arquivo)

# Lendo o arquivo JSON
json = JSON.parsefile(path)