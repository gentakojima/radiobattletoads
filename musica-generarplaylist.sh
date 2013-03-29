#!/bin/bash
#
# Este script debe ejecutarse al menos una vez antes de lanzar la radio, y cada vez que
# se añadan canciones nuevas. 
# El objetivo es crear una lista de reproducción de las músicas randomizadas. Se puede
# ejecutar tantas veces como se desee, para volver a randomizar la lista.
#
# El script trata los archivos que comiencen por $JINGLE_PREFIX como jingles y los
# coloca entre las canciones, cada $JINGLE_EVERY canciones.
#

source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/support_functions.sh

CANCIONES=$(find $RBT_MUSICADIR/ -iname '*.[mo][pg][3g]' | sort -R)
rm $RBT_MUSICADIR/playlist.m3u
CANCIONES_A=()
CUNHAS_A=()
while read line; do
	if [ -z "$(echo $line | grep /$JINGLE_PREFIX)" ] ; then
		CANCIONES_A=("${CANCIONES_A[@]}" "$line")
	else
		CUNHAS_A=("${CUNHAS_A[@]}" "$line")
	fi
done < <(echo "$CANCIONES")

NUMCUNHAS=${#CUNHAS_A[@]};

j=1
for ((i=0; i<${#CANCIONES_A[@]}; i++)); do
	j=$(($j+1))
	if [ $j -eq 2 ] ; then
		echo ${CUNHAS_A[$(($RANDOM%$NUMCUNHAS))]} >> "$RBT_MUSICADIR/playlist.m3u"
		j=0
	fi
	echo ${CANCIONES_A[i]} >> "$RBT_MUSICADIR/playlist.m3u"
done

