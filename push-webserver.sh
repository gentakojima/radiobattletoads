#!/bin/bash
#
# Radio Battletoads
# Push information to the web server (Service)
# This is a service to push current song information to the server. This is
# only needed when streaming random music.
#

source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/support_functions.sh

WGETCMD="wget -O /dev/stdout --quiet"
NOT_UPDATED_TIMES=0

while true ; do

	TRACKNAME="$($RBT_SCRIPTSDIR/interfaz-vlc.sh current artist-track)"
	if [ "a$LAST_TRACKNAME" != "a$TRACKNAME" ] || [ $NOT_UPDATED_TIMES -gt 10 ]; then
		echo "Sending track name: $TRACKNAME"
		NOT_UPDATED_TIMES=0
		LAST_TRACKNAME="$TRACKNAME"
		TRACKNAME_ESCAPED="$(echo "$TRACKNAME" | perl -lpe 's/([^A-Za-z0-9])/sprintf("%%%02X", ord($1))/seg')"
		OUTPUT="$($WGETCMD "http://$WEB_SERVER/api/calendario.php?update_song=1&key=$WEB_KEY&v=$TRACKNAME_ESCAPED")"
		if [ "a$OUTPUT" == "aneeds_artwork" ] ; then
			echo "Artwork needed"
			ARTWORK="$($RBT_SCRIPTSDIR/interfaz-vlc.sh current artwork)"
			if [ "a$ARTWORK" != "a" ] ; then
				echo "Uploading artwork: $ARTWORK"
				cp "$ARTWORK" "/tmp/$TRACKNAME"
				curl -F "file=@/tmp/$TRACKNAME" "http://$WEB_SERVER/api/calendario.php?update_song=1&key=$WEB_KEY"
			fi
		fi
	else
		NOT_UPDATED_TIMES=$(($NOT_UPDATED_TIMES+1))
	fi
	sleep 5

done
