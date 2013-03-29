#!/bin/bash
# Este script no se ejecuta normalmente de forma directa. Es llamado por otros scripts.
# El objetivo es servir de interfaz contra Icecast2. Ahora mismo solo soporta un
# comando para actualizar los metadatos del stream.
#

source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/support_functions.sh

# Borrar podcasts si está en modo borrado
if [ "a$PODCASTS_PURGE" == "atrue" ] || [ "a$PODCASTS_PURGE" == "aTRUE" ] ; then
	rm -rf $HOME/podcasts/.LOG
	rm -rf $HOME/podcasts/RBT
fi

# Descargar podcasts
podget -r 1

