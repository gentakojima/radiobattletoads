**Mandatory disclaimer:**

This software has been hacked for a particular purpose, and it might not fit
yours. You're free to fork and take this to a better quality coding status. 
And I'll be happy to receive pull requests on that direction, even when I
won't be working myself actively on that right now.

## WHAT'S THIS

This is the code running the online radio Radio Battletoads
(http://www.radiobattletoads.com). It's main features are:

  - Reading the radio schedule from Google Caledar XMLs
  - Date/time restrictions to a calendar to avoid clashes between different
    programs
  - Streams live shows by providing a streaming URL, or recorded shows by 
    providing a mp3 URL or the podcast RSS URL
  - Streams random music when there's no show scheduled
  - Shuffles jingles with the music played when there's no show scheduled
  - Uses curtains to indicate the start or ending of a program
  - Streams everything on ogg vorbis


## KNOWN ISSUES AND LIMITATIONS

  - The scheduler takes several seconds to run, so every scheduled show might
    start up to 1 minute later than expected. This is important for live shows.
  - The generated calendar is cached, so changes to a Googler Calendar won't be
    instantly reflected on the generated calendar (takes up to 3.5 minutes by 
    default for changes to take effect)
  - Podcasts are downloaded every day just once by default. If a podcast is
    published between the last night and the scheduled hour, the previous 
    episode will be aired instead
  - MP3s are downloaded every hour. If a mp3 is scheduled less than an hour
    before the show starts, the show might not be aired

## TODO

  * Remove wget dependency in favor of curl
  * Urgent cleanup: calendario.php
  * General cleanup

## CHANGELOG

  Here are listed the most important features and bugfixes only.

  [2013-04-18 @96575da9db] 
    - Fix: Radio was being cleared all the time randomly until the control.sh
      daemon was restarted. This has been addressed and fixed now.
    - Fix: Tweets were not being sended if they exceeded 140 characters.
  [2013-04-08 @c6e67c3246]
    - Change: Jingles are now shuffled properly, and all of them will be
      played before being repeated.
  [2013-04-05 @17973de3e2]
    - Change: The radio control script "control.sh" is now a daemon run by
      the init script, and not a cronjob.
  [2013-04-04 @9b089b8d48]
    - Change: The radio server is not queried by the web server anymore. All
      the communication is done FROM the radio server TO the web server. The
      radio server now provides all the info needed by the web server at
      any time. This speeds up calendario.php and simplifies its logic.

## ARCHITECTURE

The main architecture of the radio consists of:

 - WEB SERVER: Running the radio website (code not included) and the public API
 - STREAMING SERVER: Containing all bash scripts, icecast and VLC (also an 
   optional http server to provide additional information to the WEB SERVER)


## PROGRAMMING LANGUAGES

The STREAMING SERVER part is completely written in BASH. The WEB SERVER part is
completly written in PHP. NO reason for that.


## DEPENDENCIES

The WEB SERVER needs:
 - Apache 2.2
 - PHP 5.2.

The STREAMING SERVER needs:
 - Debian compatible GNU/Linux OS
 - VLC 2.0
 - Icecast 2.3
 - Ttytter 2.0
 - Podget
 - wget
 - curl
 - lame
 - libogg
 - libvorbis
 - GNU Screen


## INSTALLATION

The installation procedure is hard and can take several hours, depending on
your skills with the technologies involved. I've divided it into 5 steps:

 - Installation of the streaming server
 - Installation of the web server
 - Validation of the web server
 - Initial setup of the streaming server
 - Setup daemons and cronjobs

### STEP 1. INSTALLATION OF STREAMING SERVER

Setup a Debian or a Ubuntu server. Other GNU/Linux should also do the trick.

Create a new user just for the radio. This is not required, but highly 
recommended.

Start by installing and setting up Icecast. You must be able to send data from
any icecast source (such as VLC running on your machine, for example), and 
getting to the admin interface via HTTP. Icecast should be running all the 
time. Check that Icecast is being started on the system startup.

Install VLC. No further steps required for VLC to work.

Install GNU Screen.

Install ttytter and setup an account. The radio user should be able to tweet
by issuing the command `ttytter -status='Something else'`.

Install Podget. Configure the dir_library on the file `.podget/podgetrc` 
(i.e: dir_library=/home/radiobattletoads/podcasts) on your radio user profile.

Create the `~/scripts` directory and copy every .sh file and the .conf.dist
file inside it.

Create the `~/cunhas` directory and copy every .mp3 file from the jingles
subdirectory inside it.

Create these additional directories: `~/logs`, `~/dumps-archive`, `~/dumps`, 
`~/musica`, `~/diferidos`.

Copy the file `~/scripts/radiobattletoads.conf.dist` to `~/scripts/
radiobattletoads.conf` and setup all the values. Everything is required.
Don't try to continue without checking every single value because everything
will fail.

You might have noticed that you can change the directory locations on the 
configuration file. That should work, but it is NOT tested by now. It will 
probably make everything crash badly.


### STEP 2. INSTALLATION OF THE WEB SERVER

Place every .php file and the `programas-en-emision.xml.dist` from the 
webserver directory on the `/api` path of your webserver.

Please make sure that the webserver can write to a file named `rejects.txt` on 
the `/api` directory. Creating the file and setting rw permissions to all users
should do the trick.

Create also the directory `api/cache` and set rwx permissions to the web server 
user.

Copy the file `programas-en-emision.xml.dist` to `programas-en-emision.xml` and
set up at least one program. For each program, you must:
 - provide a name and a private URL to a different Google Calendar full XML
 - setup the accepted time frames
Everything else is optional and only intended for showing on the website.
There is no reference documentation for this file, but you can take a look at
the Radio Battletoads file at http://www.radiobattletoads.com/api and mimic it.

Copy the file `configuration.php.dist` to `configuration.php` and setup at least
the global calendar URL. You can algo setup the path to the optional features
of the step 1 and some other optional featurecandy.


### STEP 3. VALIDATION OF THE WEB SERVER

Add an entry on the calendar associated to a program on Google Calendar. After
5 minutes, it should be on the XML returned by calendar.php OR rejected, on
the rejects.txt file.

If something is not working, double check this:

 - You're actually providing Google Calendar Private full XML URLS. These URLs
   are like this: http://www.google.com/calendar/feeds/<identifier>/private-
   <another-identifier>/full
 - You're setting up the entries properly. The calendar usage is explained at
   http://wiki.radiobattletoads.com/como-emitir#programar_las_emisiones
 - The rw permissions are setup properly. Check if files are being created on
   the cache subdirectory.


### STEP 4. INITIAL SETUP OF THE STREAMING SERVER

Put at least one 44100Hz, stereo mp3 file at `~/music/`. 

Generate the first music playlist by issuing manually `~/scripts/
musica-generarplaylist.sh`.

Download the first podcasts by issuing manually `~/scripts/
podcasts-generar_serverlist.sh`, and then `~/scripts/podcasts-descargar.sh`.

Prepare the podcasts and download the mp3 files so they can be streamed by 
issuing manually `~/scripts/diferidos-preparar.sh`.

Run VLC by issuing `~/scripts/interfaz-vlc.sh run`. Check the output at
`/tmp/vlc_logging`. You might need to adjust some values again at the
configuration file to get it working. The stream should show up on the
Icecast admin interface. If not, fix that before continuing. Remember to
completely kill VLC before any new attempt: `~/scripts/interfaz-vlc.sh kill`.

Run the calendar interface to see if the calendar can be reached properly:
Issue `~/scripts/interfaz-calendario.sh ahora` to see the current program.
If you can't see anything, you must fix that before continuing.

Run the control script to see if everything behaves OK: Issue `~/scripts/
control.sh` several times at different situations and check that the radio is 
putting and removing the programs on schedule. 


### STEP 5. SETUP DAEMONS AND CRONJOBS

The control script `~/scripts/control.sh` and the script that pushes the
songs information to the webserver `~/scripts/push-webserver.sh` should be
running in background all the time.

A sampe initscript, `radiobattletoads.init` is provided. Copy it into `/etc/
init.d/radiobattletoads`, enable it by issuing as root `update-rc.d
radiobattletoads defaults`.

Other jobs must be run at difference paces, and you must setup cronjobs. A
sample cronjob file is included on the file `crontab.example`, but feel free
to adjust the times following your own needs.

The logs will tell you the commands runned, and the actions taken. Continue
looking at these logs for a while after the initial setup to check that
everything runs as expected.

## ISSUES?

If you're interested on deploying your own radio by using this code and you
run into issues, feel free to contact me at yo@jorgesuarezdelis.name.


## COPYRIGHT
 
Radio Battletoads
Copyright (C) 2013 Jorge Suárez de Lis <yo@jorgesuarezdelis.name>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

