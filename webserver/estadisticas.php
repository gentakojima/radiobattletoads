<?php 

require('configuration.php');

/* Medir rendimiento */
$performance_starttime = explode(' ', microtime());
$performance_starttime = $performance_starttime[1] + $performance_starttime[0];

/* Solo volver a cargar los stats cada 20 segundos */
$cachefile='cache/status_output';
$lockfile='cache/status_output.lock';
$cachefile_secondsold = date('U')-date('U', filectime($cachefile));
$lockfile_exists = file_exists($lockfile);
if($lockfile_exists===true) $lockfile_secondsold = date('U')-date('U', filectime($lockfile));
if($cachefile_secondsold>20 && (($lockfile_exists==true && $lockfile_secondsold>20) || ($lockfile_exists==false)) ){

        /* Crear archivo de bloqueo */
        touch($lockfile);

        /* Marcamos que estamos regenerando */
        $cachefile_secondsold=-1;

        /* Descargar los calendarios */
        setlocale(LC_ALL,'es_ES');
        date_default_timezone_set('Europe/Madrid');

        // Descargar el calendario global
        $feed = "http://$ICECAST2_USERNAME:$ICECAST2_PASSWORD@$ICECAST2_SERVER:$ICECAST2_PORT/admin/stats";
        $feedcontents = @file_get_contents($feed);
        if($feedcontents!=FALSE) file_put_contents($cachefile,$feedcontents);
        
        
        // Borrar archivo de bloqueo
        unlink($lockfile);
}

/* Generar la salida */
$doc_xml = new DOMDocument(); 
$doc_xml->load('cache/status_output');
$entries_xml = $doc_xml->getElementsByTagName('source'); 

$sources = array();
foreach ( $entries_xml as $entry_xml ) { 
        $source["nombre"] = $entry_xml->getAttributeNode('mount')->value;
        $source["oyentes"] = $entry_xml->getElementsByTagName('listeners')->item(0)->nodeValue;
        $source["slots"] = $entry_xml->getElementsByTagName('max_listeners')->item(0)->nodeValue;
        
        if($source["nombre"]=="/saltxero.ogg") $radio=$source;
        else $sources[]=$source;
}

/* Medir rendimiento */
$performance_mtime = explode(' ', microtime());
$performance_totaltime = $performance_mtime[0] + $performance_mtime[1] - $performance_starttime;

/* Salida */
header('Content-type: text/xml; charset=utf-8');
echo '<?xml version="1.0" ?>'; ?>
<root>
        <oyentes><?=$radio['oyentes']?></oyentes>
        <slots><?=$radio['slots']?></slots>
        <sources>
                <? foreach($sources as $source): ?>
                <source><?=$source["nombre"]?></source>
                <? endforeach; ?>
        </sources>
        <debug>
                <cachetime><?=$cachefile_secondsold?></cachetime>
                <gentime><?=$performance_totaltime?></gentime>
        </debug>
</root>


