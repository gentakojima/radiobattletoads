#!/bin/bash
#
# Este script debe ejecutarse cada minuto. Como es propenso a ejecutarse más de una vez sin querer, tiene
# una protección que intenta impedirlo.
# El objetivo es comprobar si se emite lo correcto por la radio, y en caso de que no sea así, enviarle
# los comandos necesarios a VLC. También twitea nuevas emisiones. También envía a ICECAST la info de la
# pista actual del VLC para que actualice los metadatos.
#

source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/support_functions.sh

BREAK_THE_RECURSION=$1

# Avoid running more than one time at once
if [ "a$BREAK_THE_RECURSION" == "a" ] && [ $(ps aux | grep control.sh | grep -v grep | wc -l) -gt 2 ] ; then
	echo "Intento de ejecutarse mas de una vez. Saliendo..."
	exit 1
fi

while true ; do

date

# Clean variables
unset nombre_programa
unset nombreprograma_limpio
unset p
unset PROGRAMA_EN_EMISION
unset PROGRAMA_EN_EMISION_DIFERIDO_HORAINICIO
unset PROGRAMA_QUE_DEBERIA_EMITIRSE
unset PROGRAMA_QUE_DEBERIA_EMITIRSE_EPISODIO
unset PROGRAMA_QUE_DEBERIA_EMITIRSE_HORAFIN
unset PROGRAMA_QUE_DEBERIA_EMITIRSE_HORAINICIO
unset PROGRAMA_QUE_DEBERIA_EMITIRSE_INFOCOMPLETA
unset PROGRAMA_QUE_DEBERIA_EMITIRSE_TIPO
unset PROGRAMA_QUE_DEBERIA_EMITIRSE_TWITTER
unset TIEMPO_DESDE_HORAINICIO
unset ENCONTRADO_EN_PLAYLIST
echo "Obteniendo información:"

echo -n "Descargando info del VLC del programa actual: "
PROGRAMA_EN_EMISION=$($RBT_SCRIPTSDIR/interfaz-vlc.sh current programa)
if [ $? -eq 1 ] ; then
        echo "[FAIL] Retrying after 30 seconds..."
        sleep 30
        continue
else
        echo "[OK]"
fi
PROGRAMA_EN_EMISION_DIFERIDO_HORAINICIO=$($RBT_SCRIPTSDIR/interfaz-vlc.sh current url | grep "file://$RBT_DIFERIDOSDIR/" | sed -r 's/file:\/\/'"$(add_slashes $RBT_DIFERIDOSDIR)"'\/.+-([0-9]+).mp3/\1/')

echo -n "Descargando info del calendario del programa que debería emitirse: "
PROGRAMA_QUE_DEBERIA_EMITIRSE_INFOCOMPLETA=$($RBT_SCRIPTSDIR/interfaz-calendario.sh ahora)
if [ $? -eq 1 ] ; then
	echo "[FAIL] Retrying after 30 seconds..."
	sleep 30
	continue
else
	echo "[OK]"
fi
PROGRAMA_QUE_DEBERIA_EMITIRSE=$(echo $PROGRAMA_QUE_DEBERIA_EMITIRSE_INFOCOMPLETA | sed -r 's/(.+):::.*:::.*:::.*:::.*/\1/')
PROGRAMA_QUE_DEBERIA_EMITIRSE_HORAINICIO=$(echo $PROGRAMA_QUE_DEBERIA_EMITIRSE_INFOCOMPLETA | sed -r 's/.+:::.*:::.*:::(.*):::.*/\1/')
PROGRAMA_QUE_DEBERIA_EMITIRSE_HORAFIN=$(echo $PROGRAMA_QUE_DEBERIA_EMITIRSE_INFOCOMPLETA | sed -r 's/.+:::.*:::.*:::.*:::(.*)/\1/')
PROGRAMA_QUE_DEBERIA_EMITIRSE_TIPO=$(echo $PROGRAMA_QUE_DEBERIA_EMITIRSE_INFOCOMPLETA | sed -r 's/.+:::.*:::(.*):::.*:::.*/\1/')
PROGRAMA_QUE_DEBERIA_EMITIRSE_EPISODIO=$(echo $PROGRAMA_QUE_DEBERIA_EMITIRSE_INFOCOMPLETA | sed -r 's/.+:::(.*):::.*:::.*:::.*/\1/')
AHORA=$(date +%s)
if [ ! -z $PROGRAMA_QUE_DEBERIA_EMITIRSE_HORAINICIO ] ; then
	TIEMPO_DESDE_HORAINICIO=$(($AHORA-$PROGRAMA_QUE_DEBERIA_EMITIRSE_HORAINICIO))
fi
nombreprograma_limpio=$(removespecialchars $PROGRAMA_QUE_DEBERIA_EMITIRSE );

if [ -z "$PROGRAMA_QUE_DEBERIA_EMITIRSE" ] ; then
	echo PROGRAMA_QUE_DEBERIA_EMITIRSE:$PROGRAMA_QUE_DEBERIA_EMITIRSE
	echo PROGRAMA_QUE_DEBERIA_EMITIRSE_INFOCOMPLETA:$PROGRAMA_QUE_DEBERIA_EMITIRSE_INFOCOMPLETA
	echo "Oops. El programa que debería emitirse está vacío? Espero un poco..."
	sleep 40
	continue
fi

ACCIONES=()

echo "Programa en emision actualmente: $PROGRAMA_EN_EMISION"
echo "Programa que deberia emitirse: $PROGRAMA_QUE_DEBERIA_EMITIRSE"
echo "Toma de deciciones:"

esta_incluido(){
	PROGRAMA_EN_EMISION=$1
	PROGRAMA_QUE_DEBERIA_EMITIRSE=$2
	nombrelimpio=$(removespecialchars $PROGRAMA_QUE_DEBERIA_EMITIRSE)
	while read line ; do
		if [ "a$line" == "a$PROGRAMA_QUE_DEBERIA_EMITIRSE" ] || [ "a$line" == "a$nombrelimpio" ] ; then
			echo true
			return
		fi
	done < <(echo "$PROGRAMA_EN_EMISION")
	echo false
}

if ( [ "a$(esta_incluido "$PROGRAMA_EN_EMISION" "$PROGRAMA_QUE_DEBERIA_EMITIRSE")" == "afalse" ] ) || 
( [ "a$PROGRAMA_QUE_DEBERIA_EMITIRSE_TIPO" == "adiferido" ] && [ "a$PROGRAMA_EN_EMISION" != "a$nombreprograma_limpio" ] ) || 
( [ "a$PROGRAMA_QUE_DEBERIA_EMITIRSE" == "a$nombreprograma_limpio" ] && [ "a$PROGRAMA_QUE_DEBERIA_EMITIRSE_HORAINICIO" != "a$PROGRAMA_EN_EMISION_DIFERIDO_HORAINICIO" ] && [ ! -z "$PROGRAMA_EN_EMISION_DIFERIDO_HORAINICIO" ] ) ; then
	echo "- No se emite el programa que deberia. Debo hacer algo? Rapido! A la batcueva!"
	vacia_please="false"
	if [ "a$PROGRAMA_EN_EMISION" == "a" ] ; then
		echo "- El programa actual es NINGUNO? Pero esto que es! Vuelvo a preguntar por si acaso."
		PROGRAMA_EN_EMISION=$($RBT_SCRIPTSDIR/interfaz-vlc.sh current programa)
		if [ "a$PROGRAMA_EN_EMISION" == "a" ] ; then
			echo "- [!] Confirmado. Vacio todo entonces."
	                vacia_please="true"
		else
			echo "- Falsa alarma."
			if [ "a$BREAK_THE_RECURSION" == "" ] ; then
				echo "- Vuelvo a empezar desde el principio..."
				$0 --no-recursion
			else
				echo "- Es la segunda falsa alarma. No hago nada, que esto es muy raro."
			fi
		fi
	elif [ "a$PROGRAMA_EN_EMISION" == "aCunha" ] ; then
		echo "- Ah, para. El programa actual es unha cunha. Puede que sea el fin/principio de un programa."
		ENCONTRADO_EN_PLAYLIST="false"
		PLAYLIST=$($RBT_SCRIPTSDIR/interfaz-vlc.sh list | sed 's/:::CURRENT//' )"\n"
		while read p; do
			ARCHIVO_DE_PLAYLIST=$(echo $p | sed -r 's/^.+:::.*:::(.+)(:::CURRENT)?$/\1/')
			NOMBRE_DE_PLAYLIST=$($RBT_SCRIPTSDIR/interfaz-calendario.sh nombre "$ARCHIVO_DE_PLAYLIST")
			if [ "a$NOMBRE_DE_PLAYLIST" == "a$PROGRAMA_QUE_DEBERIA_EMITIRSE" ] || [ "a$NOMBRE_DE_PLAYLIST" == "a$nombreprograma_limpio" ] ; then
				ENCONTRADO_EN_PLAYLIST="true"
			fi
		done < <(echo "$PLAYLIST")
		if [ "a$ENCONTRADO_EN_PLAYLIST" == "atrue" ] ; then
			echo "- El programa que deberia emitirse esta en la playlist. Todo esta bien."
		else
			echo "- [!] El programa que deberia emitirse no esta en la playlist. Vacio todo."
			vacia_please="true"
		fi
	else
		echo "- [!] Vacio todo."
		vacia_please="true"
	fi
	if [ "a" == "a$ENCONTRADO_EN_PLAYLIST" ] || [ "$ENCONTRADO_EN_PLAYLIST" == "false" ] ; then
		case $PROGRAMA_QUE_DEBERIA_EMITIRSE_TIPO in
			"directo")
				echo "- [!] Es un directo. Anhado el directo del programa que toca."
				ACCIONES=("${ACCIONES[@]}" "generacortinilla")
				if [ "a$vacia_please" == "atrue" ] ; then
					ACCIONES=("${ACCIONES[@]}" "vaciar")
				fi
	                        ACCIONES=("${ACCIONES[@]}" "directo")
				if [ "a$USE_TWITTER" == "atrue" ] || [ "a$USE_TWITTER" == "aTRUE" ] ; then
					echo "- [!] Twitter habilitado. Enviando twit."
					ACCIONES=("${ACCIONES[@]}" "twitter")
				fi
			;;
			"diferido")
				echo "- [!] Es un diferido. Anhado el mp3 con la hora de inicio y el nombre del programa."
					if [ $TIEMPO_DESDE_HORAINICIO -gt 120 ] ; then
						ACCIONES=("${ACCIONES[@]}" "generacortinilla")
						if [ "a$vacia_please" == "atrue" ] ; then
							ACCIONES=("${ACCIONES[@]}" "vaciar")
						fi
						ACCIONES=("${ACCIONES[@]}" "diferido-seek")
					else
						ACCIONES=("${ACCIONES[@]}" "generacortinilla")
						if [ "a$vacia_please" == "atrue" ] ; then
							ACCIONES=("${ACCIONES[@]}" "vaciar")
						fi
						ACCIONES=("${ACCIONES[@]}" "diferido")
					fi	
					ACCIONES=("${ACCIONES[@]}" "twitter")

			;;
			*)
				echo "- No tiene tipo. Debe ser musica. Compruebo..."
				if [ "a$PROGRAMA_QUE_DEBERIA_EMITIRSE" == "aMúsica Ininterrumpida" ] ; then
					echo "- [!] Exacto, es musica. Pues anhado la musica."
					if [ "a$vacia_please" == "atrue" ] ; then
						ACCIONES=("${ACCIONES[@]}" "vaciar")
					fi
					ACCIONES=("${ACCIONES[@]}" "musica")
				else
					echo "- No es musica. Pues estamos bien. No se que hacer. Adios!"
					exit 1
				fi
			;;
		esac
	fi
else
	echo "- Se emite el programa correcto."
	case $PROGRAMA_QUE_DEBERIA_EMITIRSE_TIPO in
		"directo")
			echo "- Es un directo."
			if [ $TIEMPO_DESDE_HORAINICIO -gt 1200 ] ; then
				echo "- Ha empezado hace mas de 20 minutos."
				# Solo hacer esta comprobacion cada 3 minutos, que es muy costosa.
				if [ $(($(expr $(date +%M) + 0)%3)) -eq 2 ] ; then
					PLAYLIST=$($RBT_SCRIPTSDIR/interfaz-vlc.sh list)
					echo $PLAYLIST | grep /cunhas/cunha1a.wav > /dev/null
					if [ $? -eq 0 ] ; then
						echo "- [!] Generando la cunha de fin..."
						ACCIONES=("${ACCIONES[@]}" "generacunhafin")
					fi
				else
					echo "- No compruebo si tiene la cunha correcta, lo hago luego."
				fi
			else
				echo "- Ha empezado hace poco. No hago nada."
			fi
		;;
		"*")
			echo "- No es un directo. No hago nada."
		;;
	esac
fi

ACCIONES=("${ACCIONES[@]}" "actualizainfostream")

#exit 2

echo "Acciones:"

for p in ${ACCIONES[@]} ; do
	case $p in
		"actualizainfostream")
			nombre_programa="$PROGRAMA_QUE_DEBERIA_EMITIRSE - $PROGRAMA_QUE_DEBERIA_EMITIRSE_EPISODIO"
			if [ ! -f /tmp/actualizainfostream.last ] || [ "a$(cat /tmp/actualizainfostream.last)" != "a$nombre_programa"  ] ; then
				echo $nombre_programa > /tmp/actualizainfostream.last
				$RBT_SCRIPTSDIR/interfaz-icecast.sh actualizainfostream "$nombre_programa"
			fi
		;;
		"vaciar")
			# Caches stream URL so VLC won't have to wait for the script to resolve the 
			# stream URL after empty the list
			if [ ! -z "$PROGRAMA_QUE_DEBERIA_EMITIRSE" ] ; then
				URL_STREAM=$($RBT_SCRIPTSDIR/interfaz-calendario.sh stream "$PROGRAMA_QUE_DEBERIA_EMITIRSE")
			fi
			$RBT_SCRIPTSDIR/interfaz-vlc.sh clear
		;;
		"directo")
			$RBT_SCRIPTSDIR/interfaz-vlc.sh addfile "$RBT_CUNHASDIR/cortinilla_generada.wav"
			if [ -z "$URL_STREAM" ] ; then 
				URL_STREAM=$($RBT_SCRIPTSDIR/interfaz-calendario.sh stream "$PROGRAMA_QUE_DEBERIA_EMITIRSE")
			fi
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhaa.wav"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhab.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhac.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhad.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhae.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhaf.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhag.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhah.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhai.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhaj.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhak.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhal.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunham.wav"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhan.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhao.mp3"
		;;
		"diferido")
			$RBT_SCRIPTSDIR/interfaz-vlc.sh addfile "$RBT_CUNHASDIR/cortinilla_generada.wav"
			nombreprograma_limpio=$(removespecialchars $PROGRAMA_QUE_DEBERIA_EMITIRSE );
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "file://$RBT_DIFERIDOSDIR/$nombreprograma_limpio-$PROGRAMA_QUE_DEBERIA_EMITIRSE_HORAINICIO.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhaa.wav"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhab.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhac.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhad.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhae.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhaf.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhag.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhah.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhai.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhaj.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhak.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhal.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunham.wav"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhan.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhao.mp3"
		;;
		"diferido-seek")
			$RBT_SCRIPTSDIR/interfaz-vlc.sh addfile "$RBT_CUNHASDIR/cortinilla_generada.wav"
			nombreprograma_limpio=$(removespecialchars $PROGRAMA_QUE_DEBERIA_EMITIRSE );
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "file://$RBT_DIFERIDOSDIR/$nombreprograma_limpio-$PROGRAMA_QUE_DEBERIA_EMITIRSE_HORAINICIO.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhaa.wav"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhab.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhac.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhad.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhae.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhaf.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhag.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhah.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhai.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhaj.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhak.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhal.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunham.wav"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhan.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunhao.mp3"
			sleep 10
			$RBT_SCRIPTSDIR/interfaz-vlc.sh seekto $(($TIEMPO_DESDE_HORAINICIO-20))
		;;
		"generacortinilla")
			$RBT_SCRIPTSDIR/announcer-tts.sh "$RBT_CUNHASDIR/announcer_base.wav" "$RBT_CUNHASDIR/cortinilla_generada.wav" "Empieza: $PROGRAMA_QUE_DEBERIA_EMITIRSE. $PROGRAMA_QUE_DEBERIA_EMITIRSE_EPISODIO"
			if [ "a$PROGRAMA_QUE_DEBERIA_EMITIRSE_TIPO" == "adiferido" ] || [ "a$PROGRAMA_QUE_DEBERIA_EMITIRSE_TIPO" == "anuevo" ] || [ "a$PROGRAMA_QUE_DEBERIA_EMITIRSE_TIPO" == "areposicion" ]  ; then
				$RBT_SCRIPTSDIR/announcer-tts.sh "$RBT_CUNHASDIR/cunhaa_base.wav" "$RBT_CUNHASDIR/cunhaa.wav" "La emisión en diferido de $PROGRAMA_QUE_DEBERIA_EMITIRSE ha terminado. En breves momentos continuará la emisión."
				$RBT_SCRIPTSDIR/announcer-tts.sh "$RBT_CUNHASDIR/cunham_base.wav" "$RBT_CUNHASDIR/cunham.wav" "Consulta la programación en radiobattletoads punto comm"
			else
				if [ ! -z "$PROGRAMA_QUE_DEBERIA_EMITIRSE_TWITTER" ] ; then
					$RBT_SCRIPTSDIR/announcer-tts.sh "$RBT_CUNHASDIR/cunhaa_base.wav" "$RBT_CUNHASDIR/cunhaa.wav" "La emisión de $PROGRAMA_QUE_DEBERIA_EMITIRSE es en directo, pero todavía no emiten señal. Consulta el twitter del programa en arroba $PROGRAMA_QUE_DEBERIA_EMITIRSE_TWITTER."
				else
					$RBT_SCRIPTSDIR/announcer-tts.sh "$RBT_CUNHASDIR/cunhaa_base.wav" "$RBT_CUNHASDIR/cunhaa.wav" "La emisión de $PROGRAMA_QUE_DEBERIA_EMITIRSE es en directo, pero todavía no emiten señal. Seguramente empezará en breves momentos."
				fi
				$RBT_SCRIPTSDIR/announcer-tts.sh "$RBT_CUNHASDIR/cunham_base.wav" "$RBT_CUNHASDIR/cunham.wav" "Consulta la programación en radiobattletoads punto comm"
			fi
		;;
		"generacortinillafin")
			if [ ! -f /tmp/generadacortinillafin ] || [ "a$(cat /tmp/generadacortinillafin 2>/dev/null)" != "a$PROGRAMA_QUE_DEBERIA_EMITIRSE" ] ; then
				echo "$PROGRAMA_QUE_DEBERIA_EMITIRSE" > /tmp/generadacortinillafin
				$RBT_SCRIPTSDIR/announcer-tts.sh "$RBT_CUNHASDIR/cunhaa_base.wav" "$RBT_CUNHASDIR/cunhaa.wav" "La emisión en directo de $PROGRAMA_QUE_DEBERIA_EMITIRSE se ha cortado. Es probable que ya haya terminado."
			fi
		;;
		"musica")
			$RBT_SCRIPTSDIR/interfaz-vlc.sh addfile "file://$RBT_MUSICADIR/playlist.m3u"
		;;
		"twitter")
			PROGRAMA_QUE_DEBERIA_EMITIRSE_TWITTER=$($RBT_SCRIPTSDIR/interfaz-calendario.sh twitter "$PROGRAMA_QUE_DEBERIA_EMITIRSE")
			if [[ "$PROGRAMA_QUE_DEBERIA_EMITIRSE_EPISODIO" != *"#prueba"* ]] ; then
				if [ ! -z "$PROGRAMA_QUE_DEBERIA_EMITIRSE_TWITTER" ] ; then
					FREECHARS=$((140 - $(echo "Empieza $PROGRAMA_QUE_DEBERIA_EMITIRSE  ($PROGRAMA_QUE_DEBERIA_EMITIRSE_TIPO) @$PROGRAMA_QUE_DEBERIA_EMITIRSE_TWITTER - http://$WEB_SERVER/"| wc -c)))
					if [ $(echo $PROGRAMA_QUE_DEBERIA_EMITIRSE_EPISODIO | wc -c) -gt $FREECHARS ] ; then
						PROGRAMA_QUE_DEBERIA_EMITIRSE_EPISODIO="$(echo $PROGRAMA_QUE_DEBERIA_EMITIRSE_EPISODIO | fold -s -w $FREECHARS | head -1)..."
					fi
					TWEET="Empieza $PROGRAMA_QUE_DEBERIA_EMITIRSE $PROGRAMA_QUE_DEBERIA_EMITIRSE_EPISODIO ($PROGRAMA_QUE_DEBERIA_EMITIRSE_TIPO) @$PROGRAMA_QUE_DEBERIA_EMITIRSE_TWITTER - http://$WEB_SERVER/"
				else
					TWEET="Empieza $PROGRAMA_QUE_DEBERIA_EMITIRSE $PROGRAMA_QUE_DEBERIA_EMITIRSE_EPISODIO ($PROGRAMA_QUE_DEBERIA_EMITIRSE_TIPO) - http://$WEB_SERVER/"
				fi
				ttytter -ssl -status="$TWEET" -autosplit=cut
			fi
		;;
	esac
done

sleep 12
done # end while true
