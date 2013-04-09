#!/bin/bash
#
# Este script no se ejecuta normalmente de forma directa. Es llamado por otros scripts.
# El objetivo es servir de interfaz contra calendario.php, el calendario de la radio
# en el servidor web. Es una interfaz de solo lectura para poder saber qué emitir en
# cada momento y, en caso de estar escuchando música, saber los metadatos de la canción.
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

WGETCMD="wget -O /dev/null --quiet"

if [ -z "$COMANDO" ] ; then
	echo "Uso: interfaz-calendario.sh COMANDO [ARGUMENTO]"
	echo " nombre URL	Busca un programa por URL de stream"
	echo " podcast NOMBRE	Busca la URL de podcast de un programa por su nombre"
	echo " stream NOMBRE	Busca la URL de streaming de un programa por su nombre"
	echo " list	Lista los programas disponibles"
	echo " diferidos	Lista las URL de los podcasts en diferido que se van a emitir"
	echo " ahora	Muestra la info del programa que se debe estar emitiendo actualmente"
	exit 1
fi

logcommand $0 $@

WGETCMD="wget -O /dev/null --quiet"

case $COMANDO in
	nombre)
		OUTPUT=""
		echo $ARGUMENTO | grep "$RBT_MUSICADIR/" > /dev/null 
		EMITIENDO_MUSICA=$?
		echo $ARGUMENTO | grep "$RBT_DIFERIDOSDIR/" > /dev/null
		EMITIENDO_DIFERIDO=$?
		echo $ARGUMENTO | grep "$RBT_CUNHASDIR/" > /dev/null
		EMITIENDO_CUNHA=$?
		if [ $EMITIENDO_MUSICA -eq 0 ] ; then
			echo "Música Ininterrumpida"
		elif [ $EMITIENDO_CUNHA -eq 0 ] ; then
			echo "Cunha"
		elif [ $EMITIENDO_DIFERIDO -eq 0 ] ; then
			RBT_DIFERIDOSDIR_REGEX=$(echo $RBT_DIFERIDOSDIR | sed 's/\//\\\//g')
			echo $(echo $ARGUMENTO | sed -r 's/^file:\/\/'"$RBT_DIFERIDOSDIR_REGEX"'\/(.+)-[0-9]+.mp3/\1/')
		else
			# Directo
			MODO=""
			wget --timeout 20 --tries=2 --quiet -O /tmp/programas $URL_PROGRAMAS
			if [ $? -ne 0 ] ; then
				exit 1
			fi
			cat /tmp/programas | while read LINE ; do
				if [ "a$MODO" == "acomparar" ] ; then MODO="" ; fi
				echo $LINE | grep "<emision>" > /dev/null && MODO="leer"
				echo $LINE | grep "</emision>" > /dev/null && MODO="comparar"
				case $MODO in
					leer)
						LINEA="";
						echo $LINE | grep "<stream>" > /dev/null
						if [ $? -eq 0 ] ; then LINEA="stream"; fi
						echo $LINE | grep "<nombre>" > /dev/null
						if [ $? -eq 0 ] ; then LINEA="nombre" ; fi
						case $LINEA in
							stream)
								CURRENT_STREAM=$(echo $LINE |sed -r 's/<stream>([^#]+).*<\/stream>/\1/')
							;;
							nombre)
								CURRENT_NOMBRE=$(echo $LINE |sed -r 's/<nombre>(.+)<\/nombre>/\1/')
							;;
						esac
					;;
					comparar)
						if [ "a$CURRENT_STREAM" == "a$ARGUMENTO" ] ; then
							echo $CURRENT_NOMBRE
						fi
						CURRENT_STREAM=""
						CURRENT_NOMBRE=""
					;;
				esac
			done
		fi
		;;
	stream|podcast|twitter)
		OUTPUT=""
                MODO=""
                wget  --timeout 20 --tries=2 --quiet -O /tmp/programas $URL_PROGRAMAS
		if [ $? -ne 0 ] ; then
			exit 1
		fi
                cat /tmp/programas | while read LINE ; do
                        if [ "a$MODO" == "acomparar" ] ; then MODO="" ; fi
                        echo $LINE | grep "<emision>" > /dev/null && MODO="leer"
                        echo $LINE | grep "</emision>" > /dev/null && MODO="comparar"
                        case $MODO in
                                leer)
                                        LINEA="";
                                        echo $LINE | grep "<$COMANDO>" > /dev/null
                                        if [ $? -eq 0 ] ; then LINEA="$COMANDO"; fi
                                        echo $LINE | grep "<nombre>" > /dev/null
                                        if [ $? -eq 0 ] ; then LINEA="nombre" ; fi
                                        case $LINEA in
                                                $COMANDO)
                                                        CURRENT_OUTPUT=$(echo $LINE |sed -r 's/<'$COMANDO'>(.+)<\/'$COMANDO'>/\1/')
                                                ;;
                                                nombre)
                                                        CURRENT_NOMBRE=$(echo $LINE |sed -r 's/<nombre>(.+)<\/nombre>/\1/')
                                                ;;
                                        esac
                                ;;
                                comparar)
                                        if [ "a$CURRENT_NOMBRE" == "a$ARGUMENTO" ] ; then
                                                echo $CURRENT_OUTPUT
                                        fi
                                ;;
                        esac
                done
	;;
	list)
                wget  --timeout 20 --tries=2 --quiet -O /tmp/programas $URL_PROGRAMAS
		if [ $? -ne 0 ] ; then
			exit 1
		fi
                cat /tmp/programas | while read LINE ; do
                	echo $LINE | grep "<nombre>" > /dev/null
                        if [ $? -eq 0 ] ; then 
				echo $LINE |sed -r 's/<nombre>(.+)<\/nombre>/\1/'
			fi
		done
	;;
	diferidos)
		wget --timeout 20 --tries=2  --quiet -O /tmp/calendario $URL_CALENDARIO
		if [ $? -ne 0 ] ; then
                        exit 1
                fi
                cat /tmp/calendario | while read LINE ; do

			if [ "a$MODO" == "asalida" ] ; then MODO="" ; fi
                        echo $LINE | grep "<emision>" > /dev/null && MODO="leer"
                        echo $LINE | grep "</emision>" > /dev/null && MODO="salida"
                        case $MODO in
                                leer)
                                        LINEA="";
                                        echo $LINE | grep -E "<urlDescarga>.+<\/urlDescarga>" > /dev/null
                                        if [ $? -eq 0 ] ; then LINEA="urlDescarga"; fi
                                        echo $LINE | grep "<programa>" > /dev/null
                                        if [ $? -eq 0 ] ; then LINEA="nombre" ; fi
					echo $LINE | grep "<horainicio>" > /dev/null
                                        if [ $? -eq 0 ] ; then LINEA="horainicio" ; fi
					echo $LINE | grep "<tipo>" > /dev/null
                                        if [ $? -eq 0 ] ; then LINEA="tipo" ; fi
                                        case $LINEA in
                                                urlDescarga)
                                                        CURRENT_OUTPUT=$(echo $LINE |sed -r 's/<urlDescarga>(.+)<\/urlDescarga>/\1/')
                                                ;;
                                                nombre)
                                                        CURRENT_NOMBRE=$(echo $LINE |sed -r 's/<programa>(.+)<\/programa>/\1/')
                                                ;;
						horainicio)
                                                        CURRENT_HORAINICIO=$(echo $LINE |sed -r 's/<horainicio>(.+)<\/horainicio>/\1/')
                                                ;;
						tipo)
							CURRENT_TIPO=$(echo $LINE |sed -r 's/<tipo>(.+)<\/tipo>/\1/')
						;;
                                        esac
                                ;;
                                salida)
                                        if [ "a$CURRENT_TIPO" == "adiferido" ] ; then 
						echo $CURRENT_NOMBRE:::$CURRENT_HORAINICIO:::$CURRENT_OUTPUT
					fi
					CURRENT_OUTPUT=""
                                ;;
                        esac
                done
	;;
	ahora)
		CURRENT_PROGRAMA=""
		CURRENT_EPISODIO=""
		CURRENT_HORAINICIO=""
		CURRENT_HORAFIN=""
		CURRENT_TIPO=""
       		wget --timeout 20 --tries=2  --quiet -O /tmp/calendario $URL_CALENDARIO
		if [ $? -ne 0 ] ; then
			exit 1
		fi
                cat /tmp/calendario | while read LINE ; do
                        if [ "a$MODO" == "asalida" ] ; then MODO="" ; fi
                        echo $LINE | grep "<ahora>" > /dev/null && MODO="leer"
                        echo $LINE | grep "</ahora>" > /dev/null && MODO="salida"
                        case $MODO in
                                leer)
                                        LINEA="";
                                        echo $LINE | grep -E "<programa>.+</programa>" > /dev/null
                                        if [ $? -eq 0 ] ; then LINEA="programa" ; fi
					echo $LINE | grep -E "<episodio>.+</episodio>" > /dev/null
                                        if [ $? -eq 0 ] ; then LINEA="episodio" ; fi
                                        echo $LINE | grep -E "<horainicio>.+</horainicio>" > /dev/null
                                        if [ $? -eq 0 ] ; then LINEA="horainicio" ; fi
					echo $LINE | grep -E "<horafin>.+</horafin>" > /dev/null
                                        if [ $? -eq 0 ] ; then LINEA="horafin" ; fi
					echo $LINE | grep -E "<tipo>.+</tipo>" > /dev/null
                                        if [ $? -eq 0 ] ; then LINEA="tipo" ; fi
                                        case $LINEA in
                                                programa)
                                                        CURRENT_PROGRAMA=$(echo $LINE |sed -r 's/<programa>(.+)<\/programa>/\1/')
                                                ;;
                                                episodio)
                                                        CURRENT_EPISODIO=$(echo $LINE |sed -r 's/<episodio>(.*)<\/episodio>/\1/')
							CURRENT_EPISODIO=$(echo $CURRENT_EPISODIO | sed 's/<!\[CDATA\[//')
							CURRENT_EPISODIO=$(echo $CURRENT_EPISODIO | sed 's/]]>//')
                                                ;;
                                                horainicio)
                                                        CURRENT_HORAINICIO=$(echo $LINE |sed -r 's/<horainicio>(.+)<\/horainicio>/\1/')
                                                ;;
                                                horafin)
                                                        CURRENT_HORAFIN=$(echo $LINE |sed -r 's/<horafin>(.+)<\/horafin>/\1/')
                                                ;;
                                                tipo)
                                                        CURRENT_TIPO=$(echo $LINE |sed -r 's/<tipo>(.+)<\/tipo>/\1/')
                                                ;;
                                        esac
                                ;;
                                salida)
                                        echo $CURRENT_PROGRAMA:::$CURRENT_EPISODIO:::$CURRENT_TIPO:::$CURRENT_HORAINICIO:::$CURRENT_HORAFIN
                                        CURRENT_OUTPUT=""
                                ;;
                        esac
                done
        ;;
esac

