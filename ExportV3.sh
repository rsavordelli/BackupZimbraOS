#!/bin/bash
###########################################################################################
# Autor: Rubem de Lima Savordelli <rsavordelli@gmail.com>
# 1) Rodar como root utilizando as opções --accounts , --listas ou --all
# 2) Rodar com usuário root
# 3) Este script exporta as contas e senhas, as listas de distribuição e os alias.
###########################################################################################
ZMPROV="/opt/zimbra/bin/zmprov"
GETLISTS="gadl"
GETMEMBERLISTS="gdl"
LISTAS="/etc/scripts/Migration/output/listas"
MEMBERS_LISTS="/etc/scripts/Migration/output/membros/"
ACCOUNTS="/etc/scripts/Migration/output/contas/accounts.txt"
USERS="/etc/scripts/Migration/output/users/"
IMPORTDIR="/etc/scripts/Migration/import/"
DOMAIN="seudominio.com.br"
SIGOUT="/etc/scripts/Migration/output/sig/"
###########################################################################################
###########################################################################################

variable=$1
case  $variable  in
	--accounts)
		echo "Iniciando --accounts"
	# Coletando as listas e contas
		echo "Coletando dados dia zmprov"
		$ZMPROV -l gaa  | egrep -v "admin@$DOMAIN|zimbra|spam|virus|ham" > $ACCOUNTS
	# Limpando o arquivo a importar
		echo "Limpando dados antigos"
		echo > $IMPORTDIR/accounts_password.zmprov
	# Exportando as contas e as senhas em SHA
		echo "Expotando os usuários e senhas"	
	for accounts in $(cat $ACCOUNTS)  ; do
	  RAMDON=`strings /dev/urandom | grep -o '[[:alnum:]]' | head -n 30 | tr -d '\n'; echo`
	  user=$($ZMPROV -l ga $accounts | egrep -i "userPassword|uid" | awk '{print $2}' | tr '\n' ' ' | awk '{print $1}')
	  password=$($ZMPROV -l ga $accounts | egrep -i "userPassword|uid" | awk '{print $2}' | tr '\n' ' ' | awk '{print $2}')
	# Salva a conta com uma senha aleatoria 
		echo "ca $user@$DOMAIN $RAMDON" >> $IMPORTDIR/accounts_password.zmprov
		echo "Exportando dados da conta $user@DOMAIN com senha $RAMDON"
	# Testa se o usuário tem senha gravada no ldap, grava apenas se tiver
  	        echo "$password" > testa_password
	        grep SSHA testa_password > /dev/null
		  result=$(echo $?)
	    if [ $result == 0 ] ; then
	        echo "ma $user@$DOMAIN userPassword $password" >> $IMPORTDIR/accounts_password.zmprov
		echo "alterando senha da conta $user@$DOMAIN para $password"
	    fi
	
	done
	;;

	--listas)
	# Coletando listas
		echo "Iniciando --listas"
		echo "Coletando listas"
		$ZMPROV $GETLISTS | grep -v zimbra > $LISTAS
	# Coletando os mesmos das listas
		echo "Coletando membros das listas"
	for listas in $(cat $LISTAS) ; do
          $ZMPROV $GETMEMBERLISTS $listas | grep zimbraMailForwardingAddress | awk -F":" '{print $2}' > $MEMBERS_LISTS/$listas
	echo "createDistributionList $listas" > $MEMBERS_LISTS/$listas.import
		for lines in $(cat $MEMBERS_LISTS/$listas) ; do
		  echo "addDistributionListMember $listas $lines" >> $MEMBERS_LISTS/$listas.import
	        done
	rm -rf $MEMBERS_LISTS/$listas
	done
	
	cat $MEMBERS_LISTS/* | sort -r > $IMPORTDIR/listas_provision.zmprov

	;;
	--all) 
		bash /etc/scripts/Migration/ExportV3.sh	--accounts
		bash /etc/scripts/Migration/ExportV3.sh	--listas
		--listas
	;;
	*)
		echo "$(tput setaf 1) Digita o parametro, brow!$(tput sgr 0)"
	    ;;
esac

echo "Os arquivos para importação estão em $IMPORTDIR/*.zmprov"
echo "====== $IMPORTDIR/listas_provision.zmprov"
echo "====== $IMPORTDIR/accounts_password.zmprov"
