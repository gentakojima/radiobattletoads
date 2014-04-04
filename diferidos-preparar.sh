#!/bin/bash
#
# Este script debe ejecutarse en un momento de baja actividad, generalmente por las noches. Puede
# ser ejecutado varias veces durante el día, tanto como se quiera, pero cuidado que no tiene
# protección contra sí mismo.
# El objetivo es obtener las emisiones en diferido y prepararlas, trascondificándolas si es 
# necesario. Ten en cuenta que para que una emisión en diferido funcione, antes ha tenido que
# ejecutarse este script, por lo que si alguien añade una emisión en diferido poco antes de 
# empezar y este script no se ha ejecutado, la emisión no funcionará correctamente.
#

source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/support_functions.sh

AYER=$(date -d yesterday +%s)
TRESAMHOY=$(date -d "today 3am" +%s)
AHORA=$(date +%s)

# Descargar URLS definidas en el calendario
# Extraer metadatos y enviárselos al servidor web

$RBT_SCRIPTSDIR/interfaz-calendario.sh diferidos | while read LINE ; do
	echo "Preparando $LINE"
	HORAINICIO=$(echo $LINE | sed -r 's/^.+:::(.+):::.*$/\1/')
	PROGRAMA=$(echo $LINE | sed -r 's/^(.+):::.+:::.*$/\1/')
	PROGRAMA_STRIPPED=$(removespecialchars $PROGRAMA)
	URL=$(echo $LINE | sed -r 's/^.+:::.+:::(.*)$/\1/')
	DESCARGADO="false"
	if [ "a$URL" != "a" ] && ( [ ! -f "$RBT_DIFERIDOSDIR/$PROGRAMA_STRIPPED-$HORAINICIO.url" ] || [ "a$(cat "$RBT_DIFERIDOSDIR/$PROGRAMA_STRIPPED-$HORAINICIO.url")" != "a$URL" ] )  ; then
		echo " - Descargando MP3"
		# Descarga el MP3. Si es una URL de iVoox, comprobar si se ha descargado correctamente
		# y sino intentar obtener la URL buena y descargarlo de allí. Si no se puede, lanza una
		# alerta
		ARCHIVO="$RBT_DIFERIDOSDIR/$PROGRAMA_STRIPPED-$HORAINICIO.mp3"
		wget --tries=10 "$URL" -O "$ARCHIVO"
		echo "$URL" | grep ivoox.com &>/dev/null
		if [ $? -eq 0 ] ; then
			file "$ARCHIVO" | grep HTML &>/dev/null
			if [ $? -eq 0 ] ; then
				echo " - Es un podcast de iVoox y lleva a una página web. Intentando arreglarlo..."
				for p in md me mf mg mh mi mj mk ; do
					URL_FIXED=$(echo "$URL" | sed -r 's/[a-z]*(_[0-9]+_[0-9]+\.mp3)/'$p'\1/')
					wget --tries=10 "$URL_FIXED" -O "$ARCHIVO"
					file "$ARCHIVO" | grep HTML &>/dev/null
					if [ $? -ne 0 ] ; then
						echo " - Arreglado! :D"
						break
					fi
				done
			fi
		fi
		DESCARGADO="true"
	else
		if [ $(($HORAINICIO-$AHORA)) -lt 86400 ] && [ $AHORA -gt $TRESAMHOY ] ; then
			echo " - Preparando podcast"
			ARCHIVO=$(ls -1 "$HOME/podcasts/RBT/$PROGRAMA/"*)
			if [ ! -f "$RBT_DIFERIDOSDIR/$PROGRAMA_STRIPPED-$HORAINICIO.mp3" ] ; then
				cp "$ARCHIVO" "$RBT_DIFERIDOSDIR/$PROGRAMA_STRIPPED-$HORAINICIO.mp3"
				DESCARGADO="true"
			else
				echo " - No haciendo nada porque ya está preparado"
			fi
		else
			echo " - No haciendo nada porque es un podcast y falta mucho"
		fi
	fi
	if [ "a$DESCARGADO" == "atrue" ] ; then
		echo " - Escribiendo duración, url y nombre de episodio "
		#ID3v1
		EMISION=$(mp3info -p %t "$RBT_DIFERIDOSDIR/$PROGRAMA_STRIPPED-$HORAINICIO.mp3" | sed -r "s/[ ]*$PROGRAMA[ ,.:-]*[ ]*//")
		#ID3v2
		if [ "a" == "a$EMISION" ] ; then 
			EMISION=$(exiftool -Title "$RBT_DIFERIDOSDIR/$PROGRAMA_STRIPPED-$HORAINICIO.mp3" | sed -E 's/^Title[ ]*: ('"$PROGRAMA"')?[ ,.:-]*(.*)[ ]*$/\2/')
		fi
		DURACION=$(mp3info -p %S "$RBT_DIFERIDOSDIR/$PROGRAMA_STRIPPED-$HORAINICIO.mp3")
		echo $URL > "$RBT_DIFERIDOSDIR/$PROGRAMA_STRIPPED-$HORAINICIO.url"
		curl "http://$WEB_SERVER/api/calendario.php?update_diferido=1&key=$WEB_KEY&programa=$(urlencode "$PROGRAMA_STRIPPED")&horainicio=$HORAINICIO&duracion=$DURACION&episodio=$(urlencode "$EMISION")&url=$(urlencode "$URL")"
		unset DURACION
	fi
done

# Borrar cosas viejas
#find $RBT_DIFERIDOSDIR/ -iname '*.mp3' | while read p ; do
#	echo "TODO"
#done

# Convertir los audios que haga falta conservando el tag titulo
find $RBT_DIFERIDOSDIR/ -iname '*.mp3' | while read p ; do 
	ORIGRATE=$(mp3info -p %Q "$p")
	ORIGCHANNELS=$(mp3info -p %o "$p")
	echo -e "$p [$ORIGRATE $ORIGCHANNELS]"
	if [ "$ORIGRATE" != "44100" ] || ( [ "$ORIGCHANNELS" != "stereo" ] && [ "$ORIGCHANNELS" != "joint stereo" ] ) ; then
		echo -ne "Convirtiendo $p... "
		#ID3v1
	        EMISION=$(mp3info -p %t "$p" | sed -r "s/[ ]*$PROGRAMA[ ,.:-]*[ ]*//")
	        #ID3v2
        	if [ "a" == "a$EMISION" ] ; then
	                EMISION=$(exiftool -Title "$p" | sed -E 's/^Title[ ]*: ('"$PROGRAMA"')?[ ,.:-]*(.*)[ ]*$/\2/')
	        fi
		mv "$p" "$p.old.mp3"
		nice -n 10 sox "$p.old.mp3" --rate 44100 --channels 2 -t wav - | lame - "$p" 2> /dev/null
		rm "$p.old.mp3"
		mp3info -t "$EMISION" "$p"
		echo " [DONE]"
	fi
done

