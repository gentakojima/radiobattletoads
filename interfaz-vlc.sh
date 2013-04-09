#!/bin/bash
#
# Este script no se ejecuta normalmente de forma directa. Es llamado por otros scripts.
# El objetivo es servir de interfaz contra VLC de lectura/escritura. Se puede consultar
# qué se emite actualmente (se apoya en la interfaz del calendario para descifrar las URL)
# y enviarle comandos, como emitir otra cosa o reiniciar la emisión.
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
	echo "Uso: vlc-control.sh COMANDO [ARGUMENTOS]"
	echo " addfile ARCHIVO	Anhade un archivo a la lista de reproduccion y lo reproduce"
	echo " addstream PROGRAMA  Anhade el stream del programa indicado a la lista de reproduccion y lo reproduce"
	echo " addpodcast PROGRAMA  Anhade el ultimo capitulo del podcast del programa indicado a la lista de reproduccion y lo reproduce"
	echo " queuefile ARCHIVO	Anhade un archivo a la lista de reproduccion"
	echo " queuestream PROGRAMA        Anhade el stream del programa indicado a la lista de reproduccion"
	echo " queuepodcast PROGRAMA        Anhade el ultimo capitulo del podcast del programa indicado a la lista de reproduccion"
	echo " delfile ARCHIVO	Borra un archivo de la lista de reproduccion"
	echo " delstream PROGRAMA	Borra el stream del programa indicado de la lista de reproduccion"
	echo " next	Avanza en la lista de reproduccion"
	echo " list	Muestra la lista de reproduccion"
	echo " kill	Mata a todo VLC viviente"
	echo " run	Ejecuta el VLC"
	echo " restart	Mata a todo VLC viviente y vuelve a ejecutarlo"
	echo " current id|name|url|programa|artist-track|artwork Show current track information"
	exit 1
fi

logcommand $0 $@

WGETCMD="wget --timeout 20 --retries 2 -O /dev/null --quiet"

case $COMANDO in
	next)
		echo -ne "Siguiente..."
		$WGETCMD "$URL_STATUS?command=pl_next"
		showok $?
	;;
	prev)
                echo -ne "Anterior..."
                $WGETCMD "$URL_STATUS?command=pl_previous"
                showok $?
        ;;
	queuefile)
		echo -ne "Encolando $ARGUMENTO..."
		$WGETCMD "$URL_STATUS?command=in_enqueue&input=$ARGUMENTO"
		showok $?
	;;
	addfile)
		echo -ne "AÃadiendo $ARGUMENTO..."
                $WGETCMD "$URL_STATUS?command=in_play&input=$ARGUMENTO"
		showok $?
        ;;
	addstream)
		echo -ne "Buscando stream de $ARGUMENTO..."
		OUTPUT=$($RBT_SCRIPTSDIR/interfaz-calendario.sh stream "$ARGUMENTO")
		if [ "a$OUTPUT" == "a" ] ; then
			echo " [FAIL!]"
		else
			echo " [OK]"
			$0 addfile $OUTPUT
		fi
	;;
	queuestream)
		echo -ne "Buscando stream de $ARGUMENTO..."
                OUTPUT=$($RBT_SCRIPTSDIR/interfaz-calendario.sh stream "$ARGUMENTO")
                if [ "a$OUTPUT" == "a" ] ; then
                        echo " [FAIL!]"
                else
                        echo " [OK]"
                        $0 queuefile $OUTPUT 
                fi
	;;
	clear)
		echo -ne "Clearing playlist..."
                $WGETCMD "$URL_STATUS?command=pl_empty"
                showok $?
	;;
	delfile)
		ARGUMENTO=$(echo $ARGUMENTO | sed 's/ /%20/g')
		wget --quiet -O /tmp/vlc_playlist $URL_PLAYLIST
		grep "$ARGUMENTO" /tmp/vlc_playlist | grep "leaf" | grep "id=" > /tmp/vlc_id
		if [ -z "$(cat /tmp/vlc_id)" ] ; then
			ARGUMENTO=$(echo $ARGUMENTO | sed 's/%20/ /g')
			grep "$ARGUMENTO" /tmp/vlc_playlist | grep "leaf" | grep "id=" > /tmp/vlc_id
		fi
		if [ ! -z "$(cat /tmp/vlc_id)" ] ; then
			OBJID=$(cat /tmp/vlc_id | sed -r 's/.*id=\"([0-9]+)\".*/\1/')
			if [ ! -z "$(cat /tmp/vlc_id | grep current=\"current\")" ] ; then
				$0 next
				sleep 1
			fi
			echo -ne "Eliminando elemento $ARGUMENTO..."
			$WGETCMD "$URL_STATUS?command=pl_delete&id=$OBJID"
			showok $?
		else
			echo -e "Eliminando elemento $ARGUMENTO... [FAIL!]"
		fi
	;;
	delstream)
		 echo -ne "Buscando stream de $ARGUMENTO..."
                OUTPUT=$($RBT_SCRIPTSDIR/interfaz-calendario.sh stream "$ARGUMENTO")
                if [ "a$OUTPUT" == "a" ] ; then
                        echo " [FAIL!]"
                else
                        echo " [OK]"
                        $0 delfile $OUTPUT
                fi
	;;
	list)
		wget --quiet -O /tmp/vlc_playlist $URL_PLAYLIST
		cat /tmp/vlc_playlist | while read LINE ; do
			echo $LINE | grep "<leaf" > /dev/null || continue;
			TRACK_ID=$(echo $LINE |sed -r 's/.*id=\"([0-9]+)\".*/\1/')
			TRACK_NAME=$(echo $LINE |sed -r 's/.*name=\"([^"]+)\".*/\1/')
			TRACK_FILE=$(echo $LINE |sed -r 's/.*uri=\"([^"]+)\".*/\1/'|sed -r 's/%20/ /g')
			echo $LINE | grep current > /dev/null
			if [ $? -eq 0 ] ; then
				# Current track
				echo -ne "$TRACK_ID:::$TRACK_NAME:::$TRACK_FILE:::CURRENT\n"
			else
				echo -ne "$TRACK_ID:::$TRACK_NAME:::$TRACK_FILE\n"
			fi
		done
	;;
	current)
		case $ARGUMENTO in
			id)
				wget --quiet -O /tmp/vlc_playlist $URL_PLAYLIST
		                LINE=`cat /tmp/vlc_playlist | grep "<leaf" | grep current`
				OUTPUT=$(echo $LINE |sed -r 's/.*id=\"([0-9]+)\".*/\1/')
				echo "$OUTPUT"
			;;
			name)
				wget --quiet -O /tmp/vlc_playlist $URL_PLAYLIST
		                LINE=`cat /tmp/vlc_playlist | grep "<leaf" | grep current`
				OUTPUT=$(echo $LINE |sed -r 's/.*name=\"([^"]+)\".*/\1/')
				echo "$OUTPUT"
			;;
			url)
				wget --quiet -O /tmp/vlc_playlist $URL_PLAYLIST
		                LINE=`cat /tmp/vlc_playlist | grep "<leaf" | grep current`
				OUTPUT=$(echo $LINE |sed -r 's/.*uri=\"([^"]+)\".*/\1/')
				echo "$OUTPUT"
			;;
			programa)
				wget --quiet -O /tmp/vlc_playlist $URL_PLAYLIST
				if [ $? -ne 0 ] ; then
					exit 1
				fi
		                LINE=`cat /tmp/vlc_playlist | grep "<leaf" | grep current`
				URL=$(echo $LINE |sed -r 's/.*uri=\"([^"]+)\".*/\1/')
				OUTPUT=$($RBT_SCRIPTSDIR/interfaz-calendario.sh nombre "$URL")
				echo "$OUTPUT"
			;;
			artist-track)
				wget --quiet -O /tmp/vlc_status $URL_STATUS
				while read LINE ; do
					echo "$LINE" | grep "name='artist'" &>/dev/null
					if [ $? -eq 0 ] ; then
						ARTIST="$(echo "$LINE" | sed -r "s/.*name='artist'>([^<]*)<\/info>.*/\1/")"
					fi
					echo "$LINE" | grep "name='title'" &>/dev/null
					if [ $? -eq 0 ] ; then
						TITLE="$(echo "$LINE" | sed -r "s/.*name='title'>([^<]*)<\/info>.*/\1/")"
					fi
				done < /tmp/vlc_status
				ARTISTTITLE="$(printf %b "${ARTIST//%/\x} - ${TITLE//%/\x}")"
				echo "$ARTISTTITLE"
			;;
			artwork)
				wget --quiet -O /tmp/vlc_status $URL_STATUS
                                while read LINE ; do
                                        echo "$LINE" | grep "name='artwork_url'" &>/dev/null
                                        if [ $? -eq 0 ] ; then
                                                ARTWORK="$(echo "$LINE" | sed -r "s/.*name='artwork_url'>file:\/\/([^<]*)<\/info>.*/\1/")"
						ARTWORK="$(printf %b "${ARTWORK//%/\x}")"
                                        fi
                                done < /tmp/vlc_status
                                echo "$ARTWORK"
			;;
			*)
				wget --quiet -O /tmp/vlc_playlist $URL_PLAYLIST
		                LINE=`cat /tmp/vlc_playlist | grep "<leaf" | grep current`
				echo "$OUTPUT"
		esac
	;;
	kill)
		VLCPID=$(pgrep -x vlc)
		[ -z $VLCPID ] && echo "No hay procesos VLC"
		for p in $VLCPID; do
			echo -ne "Matando proceso VLC $p..."
			kill $p 2>/dev/null
			sleep 2
			kill -9 $p 2>/dev/null
			echo " [OK]";
		done
	;;
	run)
		function diagnostico(){
			SALIDASABIERTAS=`cat /tmp/vlc-nohup.out | grep "mux_ogg mux: Open" | wc -l`
			OBTENIDOSTREAM=`cat /tmp/vlc-nohup.out | grep "Raw-audio server found" | wc -l`
			echo -ne "Stream de entrada obtenido: "
			if [ $OBTENIDOSTREAM -eq 1 ] ; then
				echo "1 [OK]"
			else
				echo "0 [FAIL]"
			fi
			echo -ne "Salidas abiertas: $SALIDASABIERTAS. "
			if [ $SALIDASABIERTAS -eq 2 ] ; then
			        echo "[OK]"
			else
			        echo "[FAIL]"
			fi
		}

		function replace_spaces(){
			echo $@ | sed 's/ /%20/g'
		}

		if [ ! -z "$(pgrep -f /usr/bin/vlc)" ]; then
		        echo -ne "[AVISO] Hay VLC ejecutandose. Seguro que quieres ejecutar mas? Cancela con control+c "
		        sleep 1;echo -ne ".";sleep 1;echo -ne ".";sleep 1;echo -ne ".";echo
		fi

		echo -ne "Ejecutando VLC..."
		OTHER_OPTIONS="--loop --sout-keep --sout-all --http-reconnect --file-caching=1000 --sout-mux-caching=900 --verbose=2 --extraintf=logger --logfile=/tmp/vlc-logging"
		INTF_OPTIONS="-I http --http-host $VLC_SERVER --http-port $VLC_PORT"
   		COMANDO='vlc '$OTHER_OPTIONS' '$INTF_OPTIONS' --sout #transcode{aenc=vorbis,acodec=vorb,ab='$VLC_BITRATE',channels='$VLC_CHANNELS',samplerate='$VLC_SAMPLERATE',threads=1}:gather:std{access=shout,mux=ogg,dst='$ICECAST2_MOUNT_USER':'$ICECAST2_MOUNT_PASSWORD'@'$ICECAST2_SERVER':'$ICECAST2_PORT'/'$ICECAST2_MOUNT'} '$RBT_MUSICADIR'/playlist.m3u'
		screen -d -m $COMANDO
		echo -e " [OK]"
		echo -e "Comando utilizado: $COMANDO"
		echo -ne "Escribiendo timestamp en /tmp/vlc-laststarttime..."
		echo $(date +%s) > /tmp/vlc-laststarttime
		echo -e " [OK]"
		sleep 3
	;;
	restart)
		$0 kill
		$0 run
	;;
	
esac

