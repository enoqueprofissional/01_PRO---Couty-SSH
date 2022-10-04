#!/bin/bash
# Selecionando um arquivo de texto a partir de uma caixa de diálogo
ARQUIVO=$(zenity --file-selection --title="Selecione um arquivo" --file-filter="*.sh")
# Usando o diálogo Text Information para exibir o conteúdo do arquivo selecionado:
if [ $criarteste ]
then
    zenity --text-info --title="Arquivo" --filename=$criarteste --width=450 --height=500
fi