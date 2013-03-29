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

echo "Obteniendo información:"

echo -n "Descargando info del VLC del programa actual: "
PROGRAMA_EN_EMISION=$($RBT_SCRIPTSDIR/interfaz-vlc.sh current programa)
PROGRAMA_EN_EMISION_DIFERIDO_HORAINICIO=$($RBT_SCRIPTSDIR/interfaz-vlc.sh current url | grep 'file:///home/radiobattletoads/diferidos/' | sed -r 's/file:\/\/\/home\/radiobattletoads\/diferidos\/.+-([0-9]+).mp3/\1/')
echo "[OK]"

echo -n "Descargando info del calendario del programa que debería emitirse: "
PROGRAMA_QUE_DEBERIA_EMITIRSE_INFOCOMPLETA=$($RBT_SCRIPTSDIR/interfaz-calendario.sh ahora)
echo "[OK]"
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
	if [ "a$PROGRAMA_EN_EMISION" == "a" ] ; then
		echo "- El programa actual es NINGUNO? Pero esto que es! Vuelvo a preguntar por si acaso."
		PROGRAMA_EN_EMISION=$($RBT_SCRIPTSDIR/interfaz-vlc.sh current programa)
		if [ "a$PROGRAMA_EN_EMISION" == "a" ] ; then
			echo "- [!] Confirmado. Vacio todo entonces."
	                ACCIONES=("${ACCIONES[@]}" "vaciar")
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
			ACCIONES=("${ACCIONES[@]}" "vaciar")
		fi
	else
		echo "- [!] Vacio todo."
		ACCIONES=("${ACCIONES[@]}" "vaciar")
	fi
	if [ "a" == "a$ENCONTRADO_EN_PLAYLIST" ] || [ "$ENCONTRADO_EN_PLAYLIST" == "false" ] ; then
		case $PROGRAMA_QUE_DEBERIA_EMITIRSE_TIPO in
			"directo")
				echo "- [!] Es un directo. Anhado el directo del programa que toca."
	                        ACCIONES=("${ACCIONES[@]}" "directo")
				if [ "a$USE_TWITTER" == "atrue" ] || [ "a$USE_TWITTER" == "aTRUE" ] ; then
					echo "- [!] Twitter habilitado. Enviando twit."
					ACCIONES=("${ACCIONES[@]}" "twitter")
				fi
			;;
			"diferido")
				echo "- [!] Es un diferido. Anhado el mp3 con la hora de inicio y el nombre del programa."
					ACCIONES=("${ACCIONES[@]}" "diferido")
					ACCIONES=("${ACCIONES[@]}" "twitter")
			;;
			*)
				echo "- No tiene tipo. Debe ser musica. Compruebo..."
				if [ "a$PROGRAMA_QUE_DEBERIA_EMITIRSE" == "aMúsica Ininterrumpida" ] ; then
					echo "- [!] Exacto, es musica. Pues anhado la musica."
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
					echo $PLAYLIST | grep /cunhas/cunha_1a.mp3 > /dev/null
					if [ $? -eq 0 ] ; then
						echo "- [!] Aun tiene la cunha de que empieza el directo. Debo poner la de fin!"
						ACCIONES=("${ACCIONES[@]}" "cambiacunhadirecto")
					else
						echo "- Tiene la cunha correcta. No hago nada."
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
			$RBT_SCRIPTSDIR/interfaz-vlc.sh clear
		;;
		"directo")
			$RBT_SCRIPTSDIR/interfaz-vlc.sh addfile "$RBT_CUNHASDIR/cortinilla_corta.mp3"
			URL_STREAM=$($RBT_SCRIPTSDIR/interfaz-calendario.sh stream "$PROGRAMA_QUE_DEBERIA_EMITIRSE")
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_1a.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_b.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_c.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_d.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_e.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_f.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_g.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_h.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_i.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_j.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_k.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$URL_STREAM"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_l.mp3"
		;;
		"diferido")
			$RBT_SCRIPTSDIR/interfaz-vlc.sh addfile "$RBT_CUNHASDIR/cortinilla_corta.mp3"
			nombreprograma_limpio=$(removespecialchars $PROGRAMA_QUE_DEBERIA_EMITIRSE );
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "file://$RBT_DIFERIDOSDIR/$nombreprograma_limpio-$PROGRAMA_QUE_DEBERIA_EMITIRSE_HORAINICIO.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_3a.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_b.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_c.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_d.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_e.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_f.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_g.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_h.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_i.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_j.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_k.mp3"
                        $RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_l.mp3"
		;;
		"cambiacunhadirecto")
			$RBT_SCRIPTSDIR/interfaz-vlc.sh delfile "$RBT_CUNHASDIR/cunha_1a.mp3"
			$RBT_SCRIPTSDIR/interfaz-vlc.sh queuefile "$RBT_CUNHASDIR/cunha_2a.mp3"
		;;
		"musica")
			$RBT_SCRIPTSDIR/interfaz-vlc.sh addfile "file://$RBT_MUSICADIR/playlist.m3u"
		;;
		"twitter")
			PROGRAMA_QUE_DEBERIA_EMITIRSE_TWITTER=$($RBT_SCRIPTSDIR/interfaz-calendario.sh twitter "$PROGRAMA_QUE_DEBERIA_EMITIRSE")
			if [[ "$PROGRAMA_QUE_DEBERIA_EMITIRSE_EPISODIO" != *"#prueba"* ]] ; then
				if [ ! -z "$PROGRAMA_QUE_DEBERIA_EMITIRSE_TWITTER" ] ; then
					TWEET="Empieza $PROGRAMA_QUE_DEBERIA_EMITIRSE $PROGRAMA_QUE_DEBERIA_EMITIRSE_EPISODIO ($PROGRAMA_QUE_DEBERIA_EMITIRSE_TIPO) @$PROGRAMA_QUE_DEBERIA_EMITIRSE_TWITTER - Escúchalo en http://$RBT_WEBSERVER/"
				else
					TWEET="Empieza $PROGRAMA_QUE_DEBERIA_EMITIRSE $PROGRAMA_QUE_DEBERIA_EMITIRSE_EPISODIO ($PROGRAMA_QUE_DEBERIA_EMITIRSE_TIPO) - Escúchalo en http://$RBT_WEBSERVER/"
				fi
				ttytter -status="$TWEET"
			fi
		;;
	esac
done


