#!/bin/bash
#
# Este script es opcional, se puede ejecutar con la periodicidad que se desee.
# Aunque recomendamos ejecutarlo al menos una vez cada hora, que por algo existe.
# El objetivo es detectar si el VLC o el ICECAST se han quedado lelos. Si se
# detecta, se intentan reiniciar. Nos esforzamos por no dar falsos positivos, pero
# algún caso se ha dado.
#
# Si se atasca el ICECAST no hacemos nada pero al menos lo logeamos. Si se atasca
# el VLC lo reiniciamos. Esto para las emisiones en diferido es fatal, porque vuelven
# a empezar desde el principio. FIXME
# VLC se queda atascado si se le provee una fuente de datos que no envía datos, o que
# lo mantiene a la espera. Acaba cortando la emisión o sin hacer nada, consumiendo
# toda una CPU en un estado irrecuperable. ¡Pues vaya!
#

source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/support_functions.sh

REINICIAR="FALSE"

OUTPUTFILE="/tmp/comprobacion_stream_$RANDOM"
RBTLOGFILE="${OUTPUTFILE}_log"

echo -ne "Comprobando Icecast... "
PAGINA_ICECAST=$(timeout 30 wget http://$ICECAST2_SERVER:$ICECAST2_PORT/ -O - 2>/dev/null)
if [ -z "$PAGINA_ICECAST" ] ; then
	echo "[FALLO] (no se hace nada)" # FIXME icecast se ejecuta como otro usuario y es una liada reiniciarlo
else
	echo "[OK]"
fi

echo -ne "Comprobando Stream... "
timeout 15 wget -t 1 -T 8 http://$ICECAST2_SERVER:$ICECAST2_PORT/$ICECAST2_MOUNT -O $OUTPUTFILE -o $RBTLOGFILE
grep "timed out" /tmp/comprobacion_stream_log
if [ $? -eq 0 ] ; then
	logcommand $0 estado-radio "Detectado timeout por primera vez. Volviendo a probar."
	timeout 15 wget -t 1 -T 13 http://$ICECAST2_SERVER:$ICECAST2_PORT/$ICECAST2_MOUNT -O $OUTPUTFILE.2 -o $RBTLOGFILE.2
	grep "timed out" $RBTLOGFILE.2
	if [ $? -eq 0 ] ; then
		logcommand $0 estado-radio "Detectado timeout por segunda vez. Reiniciando la radio."
		echo "[FALLO]"
		REINICIAR="TRUE"
	else
		cp $OUTPUTFILE.2 $OUTPUTFILE
	fi
fi

if [ "$REINICIAR" == "FALSE" ] ; then 
	TAMANO_STREAM=$(stat -c %s $OUTPUTFILE)
	if [ $TAMANO_STREAM -lt 50000 ] ; then
		logcommand $0 estado-radio "Detectado un tamaño anormalmente bajo <5000: $TAMANO_STREAM. Volviendo a probar."
		timeout 15 wget -t 1 -T 13 http://$ICECAST2_SERVER:$ICECAST2_PORT/$ICECAST2_MOUNT -O $OUTPUTFILE.3 -o $OUTPUTFILE_LOG.3
		TAMANO_STREAM=$(stat -c %s $OUTPUTFILE.3)
		if [ $TAMANO_STREAM -lt 50000 ] ; then
			logcommand $0 estado-radio "Detectado un tamaño anormalmente bajo <5000: $TAMANO_STREAM por segunda vez. Reiniciando la radio."
			echo "[FALLO]"
			REINICIAR="TRUE"
		fi
	fi
fi

if [ "$REINICIAR" == "TRUE" ] ; then
	echo "Reiniciado en $(date)" >> /tmp/reiniciada-radio
	$RBT_SCRIPTSDIR/interfaz-vlc.sh restart
	$RBT_SCRIPTSDIR/control.sh
else
	echo "[OK]"
fi

rm -rf $OUTPUTFILE*

