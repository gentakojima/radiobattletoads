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

while [ ${#CUNHAS_A[@]} -lt ${#CANCIONES_A[@]} ] ; do
	CUNHAS_A=("${CUNHAS_A[@]}" "${CUNHAS_A[@]}")
done

if [ $JINGLE_EVERY -gt 0 ] ; then
	# Jingles are on
	j=$(($JINGLE_EVERY-1))
	i=0
	for ((i=0; i<${#CANCIONES_A[@]}; i++)); do
		j=$(($j+1))
		if [ $j -eq $JINGLE_EVERY ] ; then
			echo ${CUNHAS_A[$i]} >> "$RBT_MUSICADIR/playlist.m3u"
			j=0
			i=$(($i+1))
		fi
		echo ${CANCIONES_A[i]} >> "$RBT_MUSICADIR/playlist.m3u"
	done
else
	# Jingles are off
	for ((i=0; i<${#CANCIONES_A[@]}; i++)); do
		echo ${CANCIONES_A[i]} >> "$RBT_MUSICADIR/playlist.m3u"
	done
fi

