import XLSX

xf = XLSX.readxlsx("docs\\TACO_tabel.xlsx")
tamanho_final = string(xf["Taco"])[37:end-2] #tamanho inteiro [35:end-1]  da tabela, "A1:FX203"
sh = xf[string("Taco!A1:", tamanho_final)] #pego a tabela hidr do A3 até o tamanho_final
