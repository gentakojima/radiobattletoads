#!/bin/bash

source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/support_functions.sh

export VOZ="es1"
export PROGRAMA_COMPLETO="$3"
export SPEECHFILE=$(mktemp).wav
export CORTINILLAFILE="$1"

# Preparar y generar speech
PROGRAMA_COMPLETO="$(echo $PROGRAMA_COMPLETO | sed -r "s/0*([0-9]+)x0*([0-9]+)/temporada \1. cap'itulo \2./")"		# Textos del tipo 2x18
PROGRAMA_COMPLETO="$(echo $PROGRAMA_COMPLETO | sed -r "s/#([0-9]+)/n'umero \1./")"					# Textos del tipo #213
PROGRAMA_COMPLETO="$(echo $PROGRAMA_COMPLETO | sed -r 's/&#[0-9a-zA-Z]+\;/. /g')"					# Borrar html entities
PROGRAMA_COMPLETO="$(echo $PROGRAMA_COMPLETO | sed -r 's/ & / y /g')"							# Ampersand
PROGRAMA_COMPLETO="$(echo $PROGRAMA_COMPLETO | sed -r 's/_/ /g')"							# Barras bajas
PROGRAMA_COMPLETO="$(echo $PROGRAMA_COMPLETO | sed 's/ - /. /g' | sed 's/(/. /g' | sed 's/)/. /g' | sed 's/ \././g')"	# Signos de puntuacion
# Diccionario
while read line ; do
	SEARCH="$(echo $line| cut -d' ' -f1)"
	REPLACE="$(echo $line| cut -d' ' -f2)"
	SEDRULE="s/$SEARCH/$REPLACE/g"
	PROGRAMA_COMPLETO="$(echo $PROGRAMA_COMPLETO | sed "$SEDRULE")"
done < $RBT_SCRIPTSDIR/announcer-tts.dictionary
echo "$PROGRAMA_COMPLETO" | iconv -f utf-8 -t iso-8859-1  | text2wave | sox - -c 2 -r 44100 $SPEECHFILE gain 10 pad 0.2 0.5 reverb phaser 0.89 0.85 1 0.24 2 -t pitch 100 dither
export DURACION_VOZ=$(soxi -D $SPEECHFILE)

# Mezclar con música
export MIX_STARTFILE=$(mktemp)
export MIX_DURINGFILE=$(mktemp).wav
export MIX_ENDFILE=$(mktemp)
export MIXED_DURINGFILE=$(mktemp).wav
sox $CORTINILLAFILE ${MIX_STARTFILE}1.wav trim 0 0.71 gain -3
sox $CORTINILLAFILE ${MIX_STARTFILE}2.wav trim 0.71 0.03 gain -5
sox $CORTINILLAFILE ${MIX_STARTFILE}3.wav trim 0.74 0.03 gain -7
sox $CORTINILLAFILE ${MIX_STARTFILE}4.wav trim 0.77 0.03 gain -10
sox $CORTINILLAFILE $MIX_DURINGFILE trim 0.8 $(echo $DURACION_VOZ + 0.21 | bc) gain -12
sox $CORTINILLAFILE ${MIX_ENDFILE}1.wav trim $(echo $DURACION_VOZ + 1.01 | bc) 0.03 gain -10
sox $CORTINILLAFILE ${MIX_ENDFILE}2.wav trim $(echo $DURACION_VOZ + 1.04 | bc) 0.03 gain -8
sox $CORTINILLAFILE ${MIX_ENDFILE}3.wav trim $(echo $DURACION_VOZ + 1.07 | bc) 0.03 gain -6
sox $CORTINILLAFILE ${MIX_ENDFILE}4.wav trim $(echo $DURACION_VOZ + 1.10 | bc) gain -4
sox -m $SPEECHFILE $MIX_DURINGFILE $MIXED_DURINGFILE
sox ${MIX_STARTFILE}1.wav ${MIX_STARTFILE}2.wav ${MIX_STARTFILE}3.wav ${MIX_STARTFILE}4.wav $MIXED_DURINGFILE ${MIX_ENDFILE}1.wav ${MIX_ENDFILE}2.wav ${MIX_ENDFILE}3.wav ${MIX_ENDFILE}4.wav $2

# Borrar archivos temporales
rm -f $SPEECHFILE $MIX_STARTFILE ${MIX_STARTFILE}1.wav ${MIX_ENDFILE}1.wav ${MIX_STARTFILE}2.wav ${MIX_STARTFILE}3.wav ${MIX_ENDFILE}2.wav ${MIX_ENDFILE}3.wav $MIX_DURINGFILE $MIXED_DURINGFILE ${MIX_ENDFILE}4.wav ${MIX_STARTFILE}4.wav


