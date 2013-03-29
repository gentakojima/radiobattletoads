#!/bin/bash

source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/radiobattletoads.conf

URL_PLAYLIST="http://$VLC_USERNAME:$VLC_PASSWORD@$VLC_SERVER:$VLC_PORT/requests/playlist.xml"
URL_STATUS="http://$VLC_USERNAME:$VLC_PASSWORD@$VLC_SERVER:$VLC_PORT/requests/status.xml"
URL_CALENDARIO="http://$WEB_SERVER/api/calendario.php"
URL_PROGRAMAS="http://$WEB_SERVER/api/programas-en-emision.xml"
URL_ICECAST="http://$ICECAST2_USERNAME:$ICECAST2_PASSWORD@$ICECAST2_SERVER:$ICECAST2_PORT/admin"

function logcommand(){
	DATE=$(date)
	COM=$@
	echo $DATE $@ >> $RBT_LOGDIR/comandos.log
	case $2 in
		addfile|addstream|queuefile|queuestream|delfile|delstream|next|kill|run|clear|random|no-random)
			 echo $DATE $@ >> $RBT_LOGDIR/acciones.log
		;;
		estado-radio)
			echo $DATE $@ >> $RBT_LOGDIR/estado-radio.log
		;;
	esac
}

function removespecialchars(){
	echo $@ | sed -r 's/[^abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]//g'
}

