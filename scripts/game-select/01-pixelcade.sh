#!/bin/bash

#
# $1 = The system identifier from ES
# $2 = The fully qualified name of the rom file
# $3 = The name of the game associated to the rom file in ES
# $4 = Reason for the event to be fired from ES
#		input         - game selected via the UI
#		randomvideo   - video being played
#		requestedgame - game selected on startup or reload * game-select only 
#		slideshow     - slideshow
#

# BASE URL for RESTful calls to Pixelcade
PIXELCADEBASEURL="http://localhost:8080/"
# name of the file that stores the last marquee selected
PREVIOUSGAMESELECTEDFILE="/home/pi/pixelcade/.marquee-select"
# get the last previously selected game for the marquee
PREVIOUSGAMESELECTED=$(cat "$PREVIOUSGAMESELECTEDFILE" 2>/dev/null)
# file to load and save the last marquee displayed to prevent blinking
PIXELCADESETTINGSFILE="/home/pi/pixelcade/settings.ini"
PIXELCADEMAPPINGSFILE="/home/pi/pixelcade/console.csv"

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

# Setting to override default behavior of the pixelcade listener. 1 - Use the system marquee if a game's marquee does not exist, 0 - Display text of the game name is a game's marquee does not exist
CONVERTWHEELARTFORMARQUEE=$(readINIFile "$PIXELCADESETTINGSFILE" "PIXELCADE SETTINGS" "ConvertWheelArtForMarquee")
USECONSOLEMARQUEEBYDEFAULT=$(readINIFile "$PIXELCADESETTINGSFILE" "PIXELCADE SETTINGS" "UseConsoleMarqueeByDefault")
USECONSOLEMARQUEEFORSCREENSAVER=$(readINIFile "$PIXELCADESETTINGSFILE" "PIXELCADE SETTINGS" "UseConsoleMarqueeForScreenSaver")

if [ "$1" != "" ] && [ "$2" != "" ] && [ "$3" != "" ]; then
	# Function to check if an image file for a game exists. 0 = true.
	image_file_exists() { if [ -f "$1.png" ] || [ -f "$1.gif" ]; then echo 0; fi }

	# get the mapped system, if it exists
	MAPPEDSYSTEM=$(grep "^$1," $PIXELCADEMAPPINGSFILE | cut -d, -f2)
	if [ "$MAPPEDSYSTEM" != "" ]; then
		SYSTEM="$MAPPEDSYSTEM"
	else
		SYSTEM="$1"
	fi

        #
        # Get rom name from fully qualified path
        #
	ROMNAME=$(basename "$2")
	ROMNAME=${ROMNAME%.*}

	#
	# CURRENTGAMESELECTED is our hash used to check if the last requested marquee is being displayed and if so don't refresh it.
	# The only time there will be a blink is if two games or systems have the same marquee one after the other.
	#
	SYSTEM="$1"
	CURRENTGAMESELECTED="$1/$ROMNAME/$3"

	# If there is no image available for the current system and game check to see if it's in a collection and use that name as the new system name.
	# This only works if the ES option "SHOW SYSTEM NAME IN COLLECTIONS" is enabled.  If not, this will default to the collection marquee, if it exists.
	# For example, 'Alien [ATARI2600]' would be the name of the game in the collection, so try to get that text, if it exists.
	MARQUEE="/home/pi/pixelcade/$SYSTEM/$ROMNAME"
	if [ "$(image_file_exists "$MARQUEE")" != "0" ]; then
		COLLECTIONSYSTEM=$(echo "$3" | sed 's/.*\[\([^]]*\)\].*/\1/g' )
		if [ "$3" != "$COLLECTIONSYSTEM" ]; then
			SYSTEM=${COLLECTIONSYSTEM,,} # Convert to lowercase and assign as the new target system
			MARQUEE="/home/pi/pixelcade/$SYSTEM/$ROMNAME"
		fi
	fi

	# If there is no marquee image, and it's enabled, use the marquee of the system
	if [ "$USECONSOLEMARQUEEBYDEFAULT" == "1" ] && [ "$(image_file_exists "$MARQUEE")" != "0" ]; then
		CURRENTGAMESELECTED="console/$SYSTEM/default"
	fi

	# Prevent blinking of the marquee if the same one is selected again.  Seems to be an issue in ES but also now needs to test if we've displayed the system logo for a game or not.
	if [ "$CURRENTGAMESELECTED" != "$PREVIOUSGAMESELECTED" ]; then
		if [ "$CURRENTGAMESELECTED" == "console/$SYSTEM/default" ]; then
			PIXELCADEURL="console/stream/"$SYSTEM""                                            # Show the marquee of the system console
		else
        		URLENCODED_FILENAME="$(rawurlencode "$ROMNAME")"
	        	URLENCODED_NAME="$(rawurlencode "$3")"
			PIXELCADEURL="arcade/stream/"$SYSTEM"/"$URLENCODED_FILENAME"?t="$URLENCODED_NAME"" # show the marquee of the game
		fi
	fi
else
	if [ "$USECONSOLEMARQUEEFORSCREENSAVER" == "1" ]; then
		# choose a random console marquee to display
		RANDOMSYSTEM="$(find /home/pi/pixelcade/console/default-*.png -type f | shuf -n 1 | sed -e 's/.*default-\(.*\).png.*/\1/')"
		CURRENTGAMESELECTED="console/$RANDOMSYSTEM/default"
		PIXELCADEURL="console/stream/$RANDOMSYSTEM"
	else
		# black out the marquee
		CURRENTGAMESELECTED="console/black/default"
		PIXELCADEURL="console/stream/black"
	fi
        if [ "$CURRENTGAMESELECTED" == "$PREVIOUSGAMESELECTED" ]; then
		PIXELCADEURL=""
	fi

fi

# Displaying a new marquee.  Set it in Pixelcade and save a token of the marquee 
if [ "$PIXELCADEURL" != "" ]; then
	curl --silent "$PIXELCADEBASEURL$PIXELCADEURL" >> /dev/null 2>/dev/null &
	echo "$CURRENTGAMESELECTED" > "$PREVIOUSGAMESELECTEDFILE"
fi

