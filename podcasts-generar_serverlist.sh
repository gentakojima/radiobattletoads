#!/bin/bash
# Este script se debe ejecutar cada vez que se añade un programa nuevo a la radio (no una emisión, sino
# un programa que antes no se emitía). No pasada nada por ejecutarlo cada pocas horas.
# El objetivo es crear la configuración de podget para que se descargue los podcasts de los programas.
#

source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/support_functions.sh

logcommand $0 $@

PODGET_SERVERLIST=$HOME/.podget/serverlist
echo "" > $PODGET_SERVERLIST

$RBT_SCRIPTSDIR/interfaz-calendario.sh list | while read PROGRAMA
do
   PODCAST=$($RBT_SCRIPTSDIR/interfaz-calendario.sh podcast "$PROGRAMA")
   echo $PODCAST RBT $PROGRAMA >> $PODGET_SERVERLIST
done
