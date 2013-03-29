#!/bin/bash
#
# Este script debe ejecutarse cada madrugada durante un momento que la radio esté parada.
# Su función es tomar el dump del día y renombrarlo, antes de que empiece un nuevo día.
# También rota los dumps anteriores (borra los más viejos). Se puede configurar los días
# que mantiene los dumps en radiobattletoads.conf
#

source $( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/support_functions.sh

mv $RBT_DUMPSDIR/dump-saltxero.ogg $RBT_DUMPSARCHIVEDIR/
CURRENT_DATE=$(date -d yesterday +"%Y-%m-%d")
rename 's/dump-/dump-'$CURRENT_DATE'-/' $RBT_DUMPSARCHIVEDIR/dump-saltxero.ogg

# Borrar dumps viejos
find $RBT_DUMPSARCHIVEDIR/ -iname '*.ogg' | while read p ; do
	FECHA=$(echo $p | sed -r 's/^.*-([0-9]+-[0-9]+-[0-9]+)-.*$/\1/')
	TIMESTAMP=$(date +%s -d "$FECHA" 2>/dev/null)
	if [ ! -z "$TIMESTAMP" ] ; then
		AHORA=$(date +%s)
		if [ $(($AHORA-$TIMESTAMP)) -gt $(($KEEPDUMPS_DAYS*86400)) ] ; then
			rm "$p"
			echo "Borrando archivo viejo $p"
		fi
	fi
done

