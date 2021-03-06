<?php

/*
* This script reads all the Google Calendars defined on the file programas-en-emision.xml
* into one, filtering out bad entries and checking that all the scheduled entries are
* within the permitted time frames.
*
* This code is an evolution of the oldest radio code from 2009. Don't expect it to be
* pretty, readable or have any sense at all.
*
* Heavy caching is used, and the calendar itself is only regenerated every $REFRESH_SECS
* seconds. Since checking all these calendars can be very time consuming it's not
* recommended lowering this value too much. And for Cthulu's sake, DON'T set it to 0.
* Even if you're debugging something, use higher values, as 30 or so.
*
* Hope you don't hate me too much after going through this.
*
*/

require('configuration.php');

/* OPTIONS END */

$opciones["ahora"] = true;
$opciones["calendario"] = true;
if($_GET["ahora"]=="0") $opciones["ahora"] = false;
if($_GET["calendario"]=="0") $opciones["calendario"] = false;
if($_GET["update_song"]=="1"){
    $opciones["update_song"] = true;
    $opciones["update_diferido"] = false;
    $opciones["ahora"] = false;
    $opciones["calendario"] = false;
    if($_GET["key"]!=$UPDATE_KEY) die("Bad key!");
}
if($_GET["update_diferido"]=="1"){
    $opciones["update_song"] = false;
    $opciones["update_diferido"] = true;
    $opciones["ahora"] = false;
    $opciones["calendario"] = false;
    if($_GET["key"]!=$UPDATE_KEY) die("Bad key!");
}

/* Modo update */
if($opciones["update_song"]==true){
    file_put_contents("cache/current_song",$_GET["v"]);
    if($_FILES["file"] && $_FILES["file"]["error"] == 0){
        if(!is_dir("cache/artwork")) mkdir("cache/artwork");
        move_uploaded_file($_FILES["file"]["tmp_name"],"cache/artwork/{$_FILES["file"]["name"]}.jpg");
    }
    $local_url = $_SERVER['DOCUMENT_ROOT']."/api/cache/artwork/{$_GET["v"]}.jpg";
    if(file_exists($local_url)) die("ok");
    else die("needs_artwork");
}
if($opciones["update_diferido"]==true){
    if($_GET["programa"]!="" && $_GET["horainicio"]!=""){
        if(!is_dir("cache/info")) mkdir("cache/info");
        if($_GET["duracion"]!="") file_put_contents("cache/info/{$_GET["programa"]}-{$_GET["horainicio"]}.duracion",$_GET["duracion"]);
        if($_GET["episodio"]!="") file_put_contents("cache/info/{$_GET["programa"]}-{$_GET["horainicio"]}.episodio",htmlentities($_GET["episodio"]));
        if($_GET["url"]!="") file_put_contents("cache/info/{$_GET["programa"]}-{$_GET["horainicio"]}.url",$_GET["url"]);
    }
    else{
        die("must_specify_programa_and_horainicio");
    }
    die("ok");
}

/* Medir rendimiento */

$performance_starttime = explode(' ', microtime());
$performance_starttime = $performance_starttime[1] + $performance_starttime[0];

/* Obtener programas y sus calendarios */

$programas_xml = new DOMDocument();
$programas_xml->load('programas-en-emision.xml');
 
$emisiones_xml = $programas_xml->getElementsByTagName('emision');

$programas = array();
foreach($emisiones_xml as $emision_xml){

        $programa['nombre'] = $emision_xml->getElementsByTagName('nombre')->item(0)->nodeValue;
        $programa['calendario'] = $emision_xml->getElementsByTagName('calendario')->item(0)->nodeValue;
        $programa['icono'] = $emision_xml->getElementsByTagName('icono')->item(0)->nodeValue;
        $programa['twitter'] = $emision_xml->getElementsByTagName('twitter')->item(0)->nodeValue;
        $programa['chat'] = $emision_xml->getElementsByTagName('chat')->item(0)->nodeValue;
        $programa['descripcion'] = $emision_xml->getElementsByTagName('descripcion')->item(0)->nodeValue;
        $programa['web'] = $emision_xml->getElementsByTagName('web')->item(0)->nodeValue;
        $programa['horarios'] = $emision_xml->getElementsByTagName('horario');
        if($programa['calendario']!=null) $programas[]=$programa;

}

/* Solo volver a cargar los calendarios cada REFRESH_SECS segundos */
$cachefile='cache/calendario_output';
$lockfile='cache/calendario_output.lock';
$cachefile_secondsold = date('U')-date('U', filectime($cachefile));
$lockfile_exists = file_exists($lockfile);
if($lockfile_exists===true) $lockfile_secondsold = date('U')-date('U', filectime($lockfile));

if( $cachefile_secondsold>$REFRESH_SECS &&
    (($lockfile_exists==true && $lockfile_secondsold>$REFRESH_SECS) || ($lockfile_exists==false))
  ){

        /* Crear archivo de bloqueo */
        touch($lockfile);

        /* Marcamos que estamos regenerando */
        $cachefile_secondsold=-1;

        /* Descargar los calendarios */

        setlocale(LC_ALL,'es_ES');
        date_default_timezone_set('Europe/Madrid');

        // Descargar el calendario global

$calendar_suffix = '?orderby=starttime&sortorder=ascending&ctz=Europe/Madrid&start-min='.urlencode(date(DATE_ATOM,time()-57600)).'&start-max='.urlencode(date(DATE_ATOM,time()+1036800));
        $feed = "$GLOBAL_CALENDAR{$calendar_suffix}";
        $cachefile = 'cache/calendario_global';
        $feedcontents = @file_get_contents($feed);
        if($feedcontents!=FALSE) file_put_contents($cachefile,$feedcontents);
        
        $calendarioglobal_xml = new DOMDocument();
        $calendarioglobal_xml->load($cachefile);

        // Ahora el resto de calendarios, y hacer un merge
        
        $rejected_entries='Última actualización: '.date('Y-m-d G:i:s');
        foreach($programas as $programa){
        
                $feed = "{$programa['calendario']}{$calendar_suffix}";
                $cachefile = "cache/calendario_{$programa["nombre"]}";
                $feedcontents = @file_get_contents($feed);
                if($feedcontents!=FALSE) file_put_contents($cachefile,$feedcontents);

                // Abre el calendario
                $calendarioprograma_xml = new DOMDocument();
                $calendarioprograma_xml->load($cachefile);

                // Hace el merge, y concatena el nombre del programa al principio del título de cada entrada
                $calendarioprograma_xml_entries = $calendarioprograma_xml->getElementsByTagName('entry');
                foreach($calendarioprograma_xml_entries as $calendarioprograma_xml_entry){
                        $node = $calendarioglobal_xml->importNode($calendarioprograma_xml_entry,true);
                        $texto_original = $node->getElementsByTagName('title')->item(0)->nodeValue;
                        $node->getElementsByTagName('title')->item(0)->removechild($node->getElementsByTagName('title')->item(0)->firstChild);
                        $node->getElementsByTagName('title')->item(0)->appendChild(new DOMText("{$programa['nombre']}:::{$texto_original}"));
                        
                        /* Comprobar si cumple horarios */
                        $times = $node->getElementsByTagName( 'when' );
                        $startTime = $times->item(0)->getAttributeNode('startTime')->value;
                        $endTime = $times->item(0)->getAttributeNode('endTime')->value;
                        $horarioprograma['inicio_timestamp'] = strtotime( $startTime );
                        $horarioprograma['fin_timestamp'] = strtotime( $endTime );
                        $horarioprograma['inicio_dia'] = date('N',(int)$horarioprograma['inicio_timestamp']);
                        $horarioprograma['inicio_hora'] = date('G:i',(int)$horarioprograma['inicio_timestamp']);
                        $horarioprograma['fin_dia'] = date('N',(int)$horarioprograma['fin_timestamp']);
                        $horarioprograma['fin_hora'] = date('G:i',(int)$horarioprograma['fin_timestamp']);
                        $cumple_horarios = false;
                        $razones=array();
                        foreach($programa['horarios'] as $horario){
                                $cumple = array('dia'=>false,'horainicio'=>false,'horafin'=>false);
                                $permitido['dia'] = $horario->getElementsByTagName('dia')->item(0)->nodeValue;
                                $permitido['horainicio'] = $horario->getElementsByTagName('horainicio')->item(0)->nodeValue;
                                $permitido['horafin'] = $horario->getElementsByTagName('horafin')->item(0)->nodeValue;
                                
                                // Comprueba dia
                                if($permitido['dia']=='*'||$permitido['dia']==$horarioprograma['inicio_dia']){
                                        $cumple['dia']=true;
                                        // Comprueba horainicio
                                        if(strtotime($horarioprograma['inicio_hora'])>=strtotime($permitido['horainicio'])){
                                                $cumple['horainicio']=true;
                                                // Comprueba hora fin
                                                if(strtotime($permitido['horafin'])<strtotime($permitido['horainicio'])){
                                                        // Es el día siguiente
                                                        $permitido['horafin']="tomorrow {$permitido['horafin']}";
                                                }
                                                if(strtotime($horarioprograma['fin_hora'])<=strtotime($permitido['horafin'])){
                                                        $cumple['horafin']=true;
                                                        $cumple_horarios = true;
                                                        break 1;
                                                }
                                        }
                                }
                                // Razones del rechazo
                                if($cumple_horarios==false){
                                        if($cumple['dia']==false) $razones[]="(Periodo día {$permitido['dia']} - Inicio {$permitido['horainicio']} - Fin {$permitido['horafin']}) Día no permitido: {$horarioprograma['inicio_dia']}";
                                        if($cumple['horainicio']==false) $razones[]="(Periodo día {$permitido['dia']} - Inicio {$permitido['horainicio']} - Fin {$permitido['horafin']}) Empieza a una hora no permitida: {$horarioprograma['inicio_hora']}";
                                        if($cumple['horafin']==false) $razones[]="(Periodo día {$permitido['dia']} - Inicio {$permitido['horainicio']} - Fin {$permitido['horafin']}) Termina a una hora no permitida: {$horarioprograma['fin_hora']}";
                                }
                        }
                        
                        /* Merge */
                        if($cumple_horarios) $calendarioglobal_xml->documentElement->appendChild($node);
                        else{
                                /* Recopila razones del rechazo */
                                $inicioalas = date('Y-m-d G:i',$horarioprograma['inicio_timestamp']);
                                $razones_string=implode("\n - ",$razones);
                                $rejected_entries.="\n * {$programa['nombre']} {$texto_original} @($inicioalas)\n - {$razones_string}";
                        }
                }
                
        }

        // Guardar el calendario con todo
        $calendarioglobal_xml->save('cache/calendario_output');
        
        // Escribir todos los rechazos
        file_put_contents('rejects.txt',$rejected_entries);
        
        // Borrar archivo de bloqueo
        @unlink($lockfile);
}

/* Generar la salida */
$doc_xml = new DOMDocument();
$doc_xml->load('cache/calendario_output');
$entries_xml = $doc_xml->getElementsByTagName('entry');

$runningShow=null;

$emisiones = array();
foreach ( $entries_xml as $entry_xml ) {

        $emision=array();
        // Hora hoy
        $emision['horahoy'] = strtotime('today 00:00:00');

        $status = $entry_xml->getElementsByTagName( 'eventStatus' );
        $eventStatus = $status->item(0)->getAttributeNode('value')->value;

        if ($eventStatus == 'http://schemas.google.com/g/2005#event.confirmed') {
        
                // Nombre
                $nombre_completo_original = $entry_xml->getElementsByTagName('title')->item(0)->nodeValue;
                $nombre_completo = preg_replace('/[ ]*#((directo)|(diferido))[ ]?.*/','',$nombre_completo_original);
                $nombre_completo_a = explode(':::',$nombre_completo);
                $emision['programa'] = $nombre_completo_a[0];
                $emision['episodio'] = $nombre_completo_a[1];
		$emision['episodio'] = trim(str_replace($nombre_completo_a[0],"",$nombre_completo_a[1]));
                
                // Tipo
                preg_match('/[ ]*#((directo)|(diferido))/',$nombre_completo_original,$matches);
                $emision['tipo'] = $matches[1];
                // Si no especifica tipo, no es una entrada valida,adios
                if($emision['tipo']!='directo' && $emision['tipo']!='diferido') continue;
                
                // Hora inicio
                $times = $entry_xml->getElementsByTagName( 'when' );
                $startTime = $times->item(0)->getAttributeNode('startTime')->value;
                $emision['horainicio'] = strtotime( $startTime );
                
                // Hora fin
                $endTime = $times->item(0)->getAttributeNode('endTime')->value;
                $emision['horafin'] = strtotime( $endTime );

                // Url descarga para podcasts en diferido
                preg_match('/[ ]*#diferido[ ]*(https?:\/\/.+)$/',$nombre_completo_original,$matches);
                $emision['urlDescarga'] = $matches[1];

                $emision['programa_saneado'] = preg_replace('/[^abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ]/','',$emision['programa']);
                // Autocompleta títulos de episodios en diferido sin título con los metadatos del MP3
                if($emision['tipo']=='diferido' && strlen($emision['episodio'])==0){
                        $emision['episodio'] = '(episodio más reciente)';
                        $episodiofile='cache/info/'."{$emision['programa_saneado']}-{$emision['horainicio']}".'.episodio';
                        if(file_exists($episodiofile)){
                                $emision['episodio'] = iconv("UTF-8","UTF-8//IGNORE",trim(file_get_contents($episodiofile)));
                        }
                }
                
                // Obtiene la duración real de episodios en diferido de los datos del MP3
                if($emision['tipo']=='diferido'){
                        $duracion=$emision['horafin']-$emision['horainicio'];
                        $duracionfile='cache/info/'."{$emision['programa_saneado']}-{$emision['horainicio']}".'.duracion';
                        if(file_exists($duracionfile)){
                                $duracion = file_get_contents($duracionfile);
                                $emision["horafinOriginal"]=$emision["horafin"];
                                // Añade 60 segundos por seguridad, sino puede que corte el programa antes de tiempo
                                if($duracion>0) $emision["horafin"]=$emision["horainicio"]+$duracion+60;
                        }                
                }
                
                // Busca icono, twitter y chat
                foreach($programas as $p){
                        if($p['nombre']==$emision['programa']){
                                $emision['icono'] = $p['icono'];
                                $emision['twitter'] = $p['twitter'];
                                $emision['chat'] = $p['chat'];
                                $emision['web'] = $p['web'];
                                $emision['descripcion'] = $p['descripcion'];
                                break 1;
                        }
                }
                
                // Variables que dicen si ha empezado, etc.
                $hasStarted = ((time()) >= $emision['horainicio'])?true:false;
                $hasEnded = ((time()) < $emision['horafin'])?false:true;
                if($hasEnded===false && $hasStarted===true) $isRunning=true;
                else $isRunning=false;
                
                $isFromThePast = (($emision['horafin'] - (time()-86400))>0)?false:true;
                // Si ya es viejo, adios
                if($isFromThePast===true) continue;
                
                // Si se está emitiendo, llenar la variable que marca el título actual
                // Si hay algo ya emitiéndose, taparlo si lo nuevo a emitir es más nuevo
                // que lo que se esté emitiendo.
                if($isRunning===true){
                        if($runningShow==null || ($runningShow["horainicio"]<$emision["horainicio"])){
                                 $runningShow=$emision;
                        }
                }
                $emisiones[] = $emision;
        }
 }

if($opciones["ahora"]==true){
    // Si la variable que marca el título actual no está llena, estamos emitiendo música ininterrumpida.
    // Conectamos a la playlist del VLC para ver la canción actual
    if($runningShow!=null) $now=$runningShow;
    else{
        $track = file_get_contents("cache/current_song");
        $now["programa"] = "Música Ininterrumpida";
        $now["episodio"] = $track;
        $local_url = $_SERVER['DOCUMENT_ROOT']."/api/cache/artwork/{$track}.jpg";
        if(file_exists($local_url)){
            $now['icono'] = "http://$WEB_SERVER/api/cache/artwork/".str_replace("?","%3F",$track).".jpg";
        }
        else{
            $now['icono'] = $ICON_MUSICA;
        }
        $now['twitter']='';
        $now['chat']='';
    }
}


/* Funciones apoyo */
function get_http_response_code($theURL) {
    $headers = get_headers($theURL);
    return substr($headers[0], 9, 3);
}

/* Medir rendimiento */
$performance_mtime = explode(' ', microtime());
$performance_totaltime = $performance_mtime[0] + $performance_mtime[1] - $performance_starttime;

/* Salida */
if($_GET["formato"]=="ical"){
header('Content-type: text/calendar; charset=utf-8');
ini_set("date.timezone","Europe/Madrid");
?>
BEGIN:VCALENDAR
VERSION:2.0
X-WR-CALNAME:Radio Battletoads
BEGIN:VTIMEZONE
TZID:<?=date("e")?>

BEGIN:STANDARD
TZNAME:<?=date("e")?>

TZOFFSETFROM:<?=date("O")?>

TZOFFSETTO:<?=date("O")?>

END:STANDARD
END:VTIMEZONE
<? foreach($emisiones as $emision): ?>
BEGIN:VEVENT
UID:<?=$emision['horainicio']?>@radiobattletoads.com
LAST-MODIFIED:<?=date("Ymd\THis",$emision['horainicio'])?>

DTSTART:<?=date("Ymd\THis",$emision['horainicio'])?>

DTEND:<?=date("Ymd\THis",$emision['horafin'])?>

CLASS:PUBLIC
SUMMARY:<?=$emision['programa']?> <?=$emision['episodio']?> (<?=$emision['tipo']?>)
DESCRIPTION:<?=$emision['twitter']?>

END:VEVENT
<? endforeach;?>
END:VCALENDAR
<? }else{
header('Content-type: text/xml; charset=utf-8');
echo '<?xml version="1.0" ?>'; ?>
<root>
<?php if($opciones["ahora"]==true): ?>
<ahora>
<programa><?=$now['programa']?></programa>
<episodio><![CDATA[<?=$now['episodio']?>]]></episodio>
<icono><?=$now['icono']?></icono>
<tipo><?=$now['tipo']?></tipo>
<horainicio><?=$now['horainicio']?></horainicio>
<horafin><?=$now['horafin']?></horafin>
<horafinOriginal><?=$now['horafinOriginal']?></horafinOriginal>
<twitter><?=$now['twitter']?></twitter>
<chat><?=$now['chat']?></chat>
<urlDescarga><?=$now['urlDescarga']?></urlDescarga>
</ahora>
<?php endif; ?>
<?php if($opciones["calendario"]==true): ?>
<calendario>
<? foreach($emisiones as $emision): ?>
<emision>
<programa><?=$emision['programa']?></programa>
<episodio><![CDATA[<?=$emision['episodio']?>]]></episodio>
<horainicio><?=$emision['horainicio']?></horainicio>
<horafin><?=$emision['horafin']?></horafin>
<horafinOriginal><?=$emision['horafinOriginal']?></horafinOriginal>
<tipo><?=$emision['tipo']?></tipo>
<descripcion><?=$emision['descripcion']?></descripcion>
<twitter><?=$emision['twitter']?></twitter>
<chat><?=$emision['chat']?></chat>
<web><?=$emision['web']?></web>
<urlDescarga><?=$emision['urlDescarga']?></urlDescarga>
</emision>
<? endforeach; ?>
</calendario>
<?php endif; ?>
<debug>
<cachetime><?=$cachefile_secondsold?></cachetime>
<gentime><?=$performance_totaltime?></gentime>
<time><?=time()?></time>
</debug>
</root>
<? } ?>
