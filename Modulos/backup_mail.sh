#!/bin/bash
# script de backup com envio automático de e-mails antes e após a
# conclusão do mesmo:.
# Autor: @Couty_SSH 
# Data: 02/06/2022

# Variáveis auxiliares:.(Utilizadas no decorrer do script)
# No exemplo esta sendo utilizado o /etc, porem fica a critério do 
# Admin/usuário escolher qual o diretório a ser backupeado:.
NOME_DIRETORIO_DESTINO="/root/backup.vps" 
export NOME_DIRETORIO_DESTINO

# Nome do diretório para onde o backup será movido, após sua 
# conclusão: (Não esqueça de verificar as permissões do diretório
# onde o backup será movido)
NOME_DIRETORIO_MOV="/mnt/backup.sh"

# Formatação da Data:Neste caso a formatação fica da seguinte forma:
# Ex:. 20/05/2012 para outras formas verifique o manual do comando 
# date com <man date>
DATA_BACKUP=$(date "+%d/%m/%y")

# Horário da realização do Backup:.
HORARIO_BACKUP=$(date|awk '{print $4}')

# Nome dos Arquivos de Log
LOG_ERRO_BACKUP="backup_info.log"

# A partir daqui são utilizadas variáveis para a autenticação do email
# que será enviado após o termino do backup, ou em caso de alguma falha
# no decorrer do backup ou após a sua conclusão.
# O software utilizado para enviar os e-mails, é o SendEmail,(sendemail)
# há uma função que verifica se o mesmo ja está instalado no servidor
# isto em distros derivadas do Debian, (.deb), porem é possível alterar
# o script para rodar em outras distribuições, para isso verifique o 
# gerenciador de pacotes que roda em sua distro e altere a função
# verifica_pckg_email() de acordo com a sua distro.

# Nome do E-mail do remetente:
NOME_EMAIL_DEST="seu-email@dominio.com.br"


# E-mail do Destinatário:
EMAIL_DESTINATARIO="e-mail-de-quem-ira-receberMSG@dominio.com.br"

# Assunto do E-mail: em branco no inicio pois o script que ira definir
# no decorrer da execução:
EMAIL_ASSUNTO=""

# Corpo da mensagem, também em branco.
EMAIL_MENSAGEM=""

# Endereço do Servidor SMTP que irá ser autenticado(neste caso o yahoo)
# Para descobrir o seu servidor SMTP, entre nas configurações do seu e-mail
# e procure por redirecionamento de e-mail, a configuração de cada um é diferente
# aqui tem alguns: 
# http://pt.kioskea.net/faq/844-enderecos-dos-servidores-pop-e-smtp-dos-principais-fai
# O 25 indica a porta Default onde o Serviço do SMTP roda, porém nem todos rodam 
# nesta mesma porta, como no caso do gmail que roda na porta 995, então
# altere a porta de acordo com a sua necessidade.
EMAIL_SMTP_ADDR="smtp.mail.yahoo.com.br:25"

# Nome do Usuário do ser provedor de e-mails:
EMAIL_USER="seu-usuario@gmail.com"

# Senha do Usuário:
EMAIL_SENHA="sua-senha"

# FIM DAS VARÍAVEIS #
#########################################################################################

# FUNÇÕES UTILIZADAS NO SCRIPT:.
# Verifica a conexão com a internet:.
# É necessário verificar no seu roteador/gateway se o ICMP não está bloqueado caso contrário
# o script não funcionara.
verifica_conexao()
{
	# teste a conexão com a internet, enviando 3 pings so google: 
	echo -e "\ntVerificando a conexão com a internet.">>$LOG_ERRO_BACKUP
	ping -c 3 www.google.com >/dev/null

	if [ $? != 0 ];then
		echo -e " $(date) ERRO: Não a conexão com a internet, ou há algum firewall/roteador
		      bloqueando o protocolo ICMP, impossibilitando o teste de conexão com a internet
		      backup abortado em $DATA_BACKUP, verifique o ocorrido e rode o backup novamente.">>$LOG_ERRO_BACKUP
		      exit 1
	else
		echo -e "$(date) INFO: Teste de conexão com a internet realizado com sucesso na data $DATA_BACKUP\n
		      Iniciando backup....">>$LOG_ERRO_BACKUP
		fi

}


# Verifica se o pacote sendemail já esta instalado, se não estiver o mesmo aborta o script:.
# em distros derivadas do Debian, caso você queira desativar esta função para rodar o script
# em outra distro, basta comentar a linha mais abaixo onde ocorre a chamada da função.
# PS:. Fora colocado um comentário acima da linha que deve ser comentada.

verifica_pckg_email()
{
	# Usando o dpkg(Debian package) a função faz uma busca, na lista de pacotes instalados
	# caso o mesmo não esteja o script encerra por aqui.
	echo -e "\ntVerificando se o pacote sendemail está instalado">>$LOG_ERRO_BACKUP
	dpkg --list|grep sendemail>/dev/null

	if [ $? != 0 ];then
		echo -e " $(date) ATENÇÃO: O pacote sendemail não está instalado, por favor, realize a instalação
			do mesmo, e rode o script novamente, o problema pode ser resolvido utilizado o  
			apt-get(apt-get-install sendemail).\n
			O script foi abortado..\n">>$LOG_ERRO_BACKUP
			exit 1
	else
		echo -e "$(date) O Pacote sendemail encontra-se instalado no servidor $(hostname)...
			\nBackup em andamento..." >>$LOG_ERRO_BACKUP
	fi

}



# Função utilizada que envia um e-mail informando o usuário/admin de que o backup está iniciando.
backup_msg_inicio()
{
	# Ajustando os valores da variáveis:.
	EMAIL_ASSUNTO="Backup do Filesystem $NOME_DIRETORIO_DESTINO iniciado, rodando no servidor $(hostname)"
	EMAIL_MENSAGEM="############### BACKUP INICIALIZADO ####################"
	
	echo -e "\nEnviado e-mail de testes.">>$LOG_ERRO_BACKUP
	# Realizado o envio da mensagem com o sendemail:
	sendemail -f $NOME_EMAIL_DEST -t $EMAIL_DESTINATARIO  -u $EMAIL_ASSUNTO  -m $EMAIL_MENSAGEM -s $EMAIL_SMTP_ADDR  -xu $EMAIL_USER  -xp $EMAIL_SENHA>info_smtp.tmp
	if [ $? != 0 ];then
		echo -e "$(date) ERRO: Problema ao enviar e-mail, abaixo verifique a saida do sendemail para constatar
			  	 o problema, e então rode o backup novamente:	
				 $(cat info_smtp.tmp).\n">>$LOG_ERRO_BACKUP
				 rm info_smtp.tmp
				 exit 1
	else
		echo -e "$(date) E-mail de testes enviado com sucesso, backup em andamento..">>$LOG_ERRO_BACKUP
	fi

}

# Funções do backup propiamente dito (.tar.gz)
# Tamanho do backup
backup_size(){  du -hs "$1" | cut -f1; }

# Verificando enquanto a cópia do backup esta rodando
backup_rodando()
{
	
	ps $1 | grep $1 >/dev/null

}


# Auxiliar
AUX=$(echo $NOME_DIRETORIO_DESTINO| cut -d"/" -f2)

# função que inicia o backup
backup_start()
{
	# mensagem no arquivo de log
	echo -e "\n######### INICIANDO BACKUP ##########.">>$LOG_ERRO_BACKUP

	# inico do Backu
	/usr/bin/time -p -o info_time tar -cvzf ${AUX}`date +%Y_%m_%d__%H_%M_%S`.tar.gz "$1"

}


envia_msg_backup()
{
	# após a realização do backup envia uma mensagem informando a realização correta
	# do backup com o nome do arquivo gerado.
	NOME_ARQUIVO=$(ls -la *.tar.gz|cut -d" " -f8)

	# Ajustando o valor das varíaveis:
	EMAIL_ASSUNTO="Backup do FileSystem $NOME_DIRETORIO_DESTINO realizado com sucesso na data $(date)"
	EMAIL_MENSAGEM="Atencao o backup de $NOME_DIRETORIO_DESTINO foi realizado com sucesso na data $(date).\n
			\n
			#############################################################################
			\n
			\nInformacoes:\n
			\nNome do Diretorio a ser backupeado: $NOME_DIRETORIO_DESTINO.\n
			\nNome do Arquivo final: $NOME_ARQUIVO.\n
			\nTempo de Execucao do backup:\n
			$(cat info_time)\n
			\nNome do arquivo de Log: $LOG_ERRO_BACKUP\n
			\nData de criacao do Backup: $DATA_BACKUP\n
			\nHorario de Criacao do Backup: $HORARIO_BACKUP\n
			\n
			#############################################################################
			\n
			"
			rm info_time

        # Realizado o envio da mensagem com o sendemail:
        sendemail -f $NOME_EMAIL_DEST -t $EMAIL_DESTINATARIO  -u $EMAIL_ASSUNTO  -m $EMAIL_MENSAGEM -s $EMAIL_SMTP_ADDR  -xu $EMAIL_USER  -xp $EMAIL_SENHA>>$LOG_ERRO_BACKUP
        if [ $? != 0 ];then
                echo -e "$(date) ERRO: Problema ao enviar e-mail, abaixo verifique a saida do sendemail para constatar
                                 o problema, e então rode o backup novamente:   
                                 $(cat info_smtp.tmp).\n">>$LOG_ERRO_BACKUP
                                 rm info_smtp.tmp
                                 exit 1
        else
                echo -e "$(date)  backup finalizado com sucesso\n..">>$LOG_ERRO_BACKUP
        fi




}

# Função que move o backup realizado para o diretório informado no inicio do script:
move_backup()
{
	echo "$(date) INFO: Movendo o arquivo $NOME_ARQUIVO para o diretório $NOME_DIRETORIO_MOV.">>$LOG_ERRO_BACKUP
	/usr/bin/time -p -o info_mv mv $NOME_ARQUIVO $NOME_DIRETORIO_MOV
	if [ $? != 0 ];then
		      # mensagem de sucesso
		      INFO_ERRO="Anteção ouve um erro ao mover o arquivo $NOME_ARQUIVO para o diretório $NOME_DIRETORIO_MOV,
		      verifique o ocorrido, e tente move-lo manualmente."

                      sendemail -f $NOME_EMAIL_DEST -t $EMAIL_DESTINATARIO  -u "ERRO na Alocação do Backup $NOME_ARQUIVO"  -m $INFO_ERRO -s $EMAIL_SMTP_ADDR  -xu $EMAIL_USER  -xp $EMAIL_SENHA>>$LOG_ERRO_BACKUP

		      echo $INFO_ERRO>>$LOG_ERRO_BACKUP

		      rm info_mv
		

		
	else
		     # mensagem de erro
                     INFO_OK="O arquivo $NOME_ARQUIVO foi movido com sucesso para o diretório $NOME_DIRETORIO_MOV,
                     na data $(date) com o tempo de $(cat info_mv)"
                    sendemail -f $NOME_EMAIL_DEST -t $EMAIL_DESTINATARIO  -u "Alocação do Backup $NOME_ARQUIVO realizado com sucesso"  -m $INFO_OK -s $EMAIL_SMTP_ADDR  -xu $EMAIL_USER  -xp $EMAIL_SENHA

		    echo $INFO_OK>>$LOG_ERRO_BACKUP
		    
   		    rm info_mv
	fi



}

# Disparando as funções do script
verifica_conexao
# Para rodar em outra distro basta comentar (Colocar um # na frente) da linha abaixo. onde se econtra verifica_pckg_email.
verifica_pckg_email	
backup_msg_inicio
backup_start $NOME_DIRETORIO_DESTINO
envia_msg_backup
move_backup

# Fim #####################################################################




