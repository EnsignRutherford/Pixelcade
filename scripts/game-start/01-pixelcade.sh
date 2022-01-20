#!/bin/bash

#
# $1 = The fully qualified name of the rom file
# $2 = The name of the rom associated to the rom file
# $3 = The description of the game associated to the rom file
#

#
# Write these commands to a separate bash script and execute as a new process so it doesn't tie up game starting
#
# 1. Saves the current selected game
# 2. If configured, displays the "Now Loading..." animated gif on the pixelcade else scrolls "Now Loading " and the game description
# 3. Waits 11 seconds
# 4. Sets the current selected game's logo (or the system logo using existing logic in game-select script
# 5. Writes the previous selected game back
#
# This should prevent flickering after the game is exited. 
#
# file to load and save the last marquee displayed to prevent blinking
PIXELCADESETTINGSFILE="/home/pi/pixelcade/settings.ini"

#
# Key lookup function
#
function readINIFile() {
    if [[ -f "$1" ]] ; then
        sed -nr "/^\[$2\]/ { :l /^$3[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" "$1" 2>/dev/null
    else
        echo ""
    fi
}

#
# this is needed for rom names with non-html compatible characters
#
function rawurlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"
}

SHOWNOWLOADINGGAMENAME=$(readINIFile "$PIXELCADESETTINGSFILE" "PIXELCADE SETTINGS" "ShowNowLoadingGameName")
SYSTEM=$(basename $(dirname "$1"))
URLENCODED_NAME="$(rawurlencode "$3")"
if [ "$SYSTEM" != "retropiemenu" ]; then #ignore the options menu
	PREVIOUSGAMESELECTEDFILE="/home/pi/pixelcade/.marquee-select"
	PREVIOUSGAMESELECTED=$(cat "$PREVIOUSGAMESELECTEDFILE" 2>/dev/null)
        if [ "$SHOWNOWLOADINGGAMENAME" == "1" ]; then
		echo "curl --silent \"http://localhost:8080/text?t=Now%20Loading%20$URLENCODED_NAME&color=green&font=ARCADE_I&yoffset=-2\"  > /dev/null 2>/dev/null" > /home/pi/pixelcade/.game-start.sh
	else
		echo "curl --silent "http://localhost:8080/console/stream/nowloading"  > /dev/null 2>/dev/null" > /home/pi/pixelcade/.game-start.sh
	fi
	echo "sleep 11s" >> /home/pi/pixelcade/.game-start.sh
	echo "rm -f \""$PREVIOUSGAMESELECTEDFILE"\" >/dev/null 2>/dev/null" >> /home/pi/pixelcade/.game-start.sh
	echo  "/home/pi/.emulationstation/scripts/game-select/01-pixelcade.sh  \"$(basename $(dirname "$1"))\" \"$(basename "$1")\" \"$2\"" >> /home/pi/pixelcade/.game-start.sh
	echo "echo \""$PREVIOUSGAMESELECTED"\" > \""$PREVIOUSGAMESELECTEDFILE"\"" >> /home/pi/pixelcade/.game-start.sh

	echo "curl --silent "http://localhost:8080/console/stream/gameover"  > /dev/null 2>/dev/null" > /home/pi/pixelcade/.game-end.sh
	echo "sleep 2s" >> /home/pi/pixelcade/.game-end.sh
	echo "rm -f \""$PREVIOUSGAMESELECTEDFILE"\" >/dev/null 2>/dev/null" >> /home/pi/pixelcade/.game-end.sh
	echo  "/home/pi/.emulationstation/scripts/game-select/01-pixelcade.sh  \"$(basename $(dirname "$1"))\" \"$(basename "$1")\" \"$2\"" >> /home/pi/pixelcade/.game-end.sh
	echo "echo \""$PREVIOUSGAMESELECTED"\" > \""$PREVIOUSGAMESELECTEDFILE"\"" >> /home/pi/pixelcade/.game-end.sh

	chmod +x /home/pi/pixelcade/.game-start.sh
	chmod +x /home/pi/pixelcade/.game-end.sh

	/home/pi/pixelcade/.game-start.sh > /dev/null 2>/dev/null &
else
	rm -f /home/pi/pixelcade/.game-start.sh > /dev/null 2>/dev/null
	rm -f /home/pi/pixelcade/.game-end.sh > /dev/null 2>/dev/null
fi


