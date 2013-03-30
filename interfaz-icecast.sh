#!/bin/bash
#
# Este script no se ejecuta normalmente de forma directa. Es llamado por otros scripts.
# El objetivo es servir de interfaz contra Icecast2. Ahora mismo solo soporta un
# comando para actualizar los metadatos del stream.
#


source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/support_functions.sh

COMANDO=$1
ARGUMENTO=$2

function showok(){
	if [ $1 -eq 0 ] ; then
		echo " [OK]"
	else
		echo " [FAIL!]"
	fi
}

if [ -z "$COMANDO" ] ; then
	echo "Uso: interfaz-icecast.sh COMANDO [ARGUMENTOS]"
	echo " actualizainfostream ARCHIVO	Actualiza info del stream en el icecast"
	exit 1
fi

logcommand $0 $@

WGETCMD="wget -O /dev/null --quiet"

case $COMANDO in
	actualizainfostream)
		echo -ne "Actualizando info stream..."
		ARGUMENTO=$(echo "$ARGUMENTO" | sed 's/&#39;/'\''/')
		wget "$URL_ICECAST/metadata?mount=/$ICECAST2_MOUNT&mode=updinfo&song=$ARGUMENTO"
		showok $?
	;;
esac
