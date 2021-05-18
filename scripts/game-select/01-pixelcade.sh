#!/bin/bash

#
# $1 = The system identifier from ES
# $2 = The name of the rom file
# $3 = The name of the game associated to the rom file
#

# BASE URL for RESTful calls to Pixelcade
PIXELCADEBASEURL="http://localhost:8080/"
# name of the file that stores the last marquee selected
PREVIOUSGAMESELECTEDFILE="/home/pi/pixelcade/.game-select"
# get the last previously selected game for the marquee
PREVIOUSGAMESELECTED=$(cat "$PREVIOUSGAMESELECTEDFILE" 2>/dev/null)

if [ "$1" != "" ] && [ "$2" != "" ] && [ "$3" != "" ]; then 
	# Function to check if an image file for a game exists. 0 = true.
	image_file_exists() { if [ -f "$1.png" ] || [ -f "$1.gif" ]; then echo 0; fi }

	# file to load and save the last marquee displayed to prevent blinking
	PREVIOUSGAMESELECTEDFILE="/home/pi/pixelcade/.game-select"
	PIXELCADESETTINGSFILE="/home/pi/pixelcade/settings.ini"
	PIXELCADEMAPPINGSFILE="/home/pi/pixelcade/console.csv"

	# Setting to override default behavior of the pixelcade listener. 1 - Use the system marquee if a game's marquee does not exist, 0 - Display text of the game name is a game's marquee does not exist
	USECONSOLEMARQUEEBYDEFAULT=$(sed -nr "/^\[PIXELCADE SETTINGS\]/ { :l /^UseConsoleMarqueeByDefault[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" "$PIXELCADESETTINGSFILE" 2>/dev/null)
	CONVERTWHEELARTFORMARQUEE=$(sed -nr "/^\[PIXELCADE SETTINGS\]/ { :l /^ConvertWheelArtForMarquee[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" "$PIXELCADESETTINGSFILE" 2>/dev/null)

	# get the mapped system, if it exists
	MAPPEDSYSTEM=$(grep "^$1," $PIXELCADEMAPPINGSFILE | cut -d, -f2)
	if [ "$MAPPEDSYSTEM" != "" ]; then
		SYSTEM="$MAPPEDSYSTEM"
	else
		SYSTEM="$1"
	fi

	#
	# CURRENTGAMESELECTED is our hash used to check if the last requested marquee is being displayed and if so don't refresh it.
	# The only time there will be a blink is if two games or systems have the same marquee one after the other.
	#
	SYSTEM="$1"
	CURRENTGAMESELECTED="$1/$2/$3"

	# If there is no image available for the current system and game check to see if it's in a collection and use that name as the new system name.
	# This only works if the ES option "SHOW SYSTEM NAME IN COLLECTIONS" is enabled.  If not, this will default to the collection marquee, if it exists.
	# For example, 'Alien [ATARI2600]' would be the name of the game in the collection, so try to get that text, if it exists.
	MARQUEE="/home/pi/pixelcade/$SYSTEM/${2%.*}"
	if [ "$(image_file_exists "$MARQUEE")" != "0" ]; then
		COLLECTIONSYSTEM=$(echo "$3" | sed 's/.*\[\([^]]*\)\].*/\1/g' )
		if [ "$3" != "$COLLECTIONSYSTEM" ]; then
			SYSTEM=${COLLECTIONSYSTEM,,} # Convert to lowercase and assign as the new target system
			MARQUEE="/home/pi/pixelcade/$SYSTEM/${2%.*}"
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
        		URLENCODED_FILENAME="$(python -c "import urllib, sys; print urllib.quote(sys.argv[1])" "$2")"
	        	URLENCODED_NAME="$(python -c "import urllib, sys; print urllib.quote(sys.argv[1])" "$3")"
			PIXELCADEURL="arcade/stream/"$SYSTEM"/"$URLENCODED_FILENAME"?t="$URLENCODED_NAME"" # show the marquee of the game
		fi
	fi
else
	# black out the marquee
	CURRENTGAMESELECTED="console/black/default"
	if [ "$CURRENTGAMESELECTED" != "$PREVIOUSGAMESELECTED" ]; then
		PIXELCADEURL="console/stream/black"
	fi
fi

if [ "$PIXELCADEURL" != "" ]; then
	curl --silent "$PIXELCADEBASEURL$PIXELCADEURL" >> /dev/null 2>/dev/null &
	echo "$CURRENTGAMESELECTED" > "$PREVIOUSGAMESELECTEDFILE"
fi

