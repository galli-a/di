#!/usr/bin/env zsh -f
# Purpose: 	Download and install the latest version of m4vgear
#
# From:		Timothy J. Luoma
# Mail:		luomat at gmail dot com
# Date:		2015-10-29
# Verified:	2025-02-24

NAME="$0:t:r"

INSTALL_TO='/Applications/M4VGear.app'

HOMEPAGE="http://www.m4vgear.com/"

DOWNLOAD_PAGE="https://www.m4vgear.com/m4vgear.dmg"

SUMMARY="Strip DRM from purchased iTunes movies and TV shows."

XML_FEED="http://www.m4vgear.com/feed-m4vgear.xml"

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
fi

INFO=($(curl -sfL "$XML_FEED" | tr -s ' ' '\012' | egrep "^url=|sparkle:version=" | awk -F'"' '//{print $2}'))

URL="$INFO[1]"

LATEST_VERSION="$INFO[2]"

	# If any of these are blank, we should not continue
if [ "$INFO" = "" -o "$LATEST_VERSION" = "" -o "$URL" = "" ]
then
	echo "$NAME: Error: bad data received:
	INFO: $INFO
	LATEST_VERSION: $LATEST_VERSION
	URL: $URL
	"

	exit 1
fi

if [[ -e "$INSTALL_TO" ]]
then

	INSTALLED_VERSION=`defaults read "$INSTALL_TO/Contents/Info" CFBundleVersion 2>/dev/null || echo '0'`

	if [[ "$LATEST_VERSION" == "$INSTALLED_VERSION" ]]
	then
		echo "$NAME: Up-To-Date ($INSTALLED_VERSION)"
		exit 0
	fi

	autoload is-at-least

	is-at-least "$LATEST_VERSION" "$INSTALLED_VERSION"

	if [ "$?" = "0" ]
	then
		echo "$NAME: Installed version ($INSTALLED_VERSION) is ahead of official version $LATEST_VERSION"
		exit 0
	fi

	echo "$NAME: Outdated (Installed = $INSTALLED_VERSION vs Latest = $LATEST_VERSION)"

fi

RELEASE_NOTES_URL="$XML_FEED"

FILENAME="$HOME/Downloads/$INSTALL_TO:t:r-$LATEST_VERSION.dmg"

(echo -n "$NAME: Release Notes for " ;
	curl -sfL "$RELEASE_NOTES_URL" \
	| perl -p -e 's/<description>/\n<description>\n/ ; s/<\/description>/\n<\/description>\n/' \
	| sed '1,/<description>/d; /<\/description>/,$d' ;
	echo "\nSource: XML_FEED <$RELEASE_NOTES_URL>" ) | tee "$FILENAME:r.txt"

echo "$NAME: Downloading $URL to $FILENAME"

curl --continue-at - --fail --location --output "$FILENAME" "$URL"

EXIT="$?"

	## exit 22 means 'the file was already fully downloaded'
[ "$EXIT" != "0" -a "$EXIT" != "22" ] && echo "$NAME: Download of $URL failed (EXIT = $EXIT)" && exit 0

[[ ! -e "$FILENAME" ]] && echo "$NAME: $FILENAME does not exist." && exit 0

[[ ! -s "$FILENAME" ]] && echo "$NAME: $FILENAME is zero bytes." && rm -f "$FILENAME" && exit 0

MNTPNT=$(hdiutil attach -nobrowse -plist "$FILENAME" 2>/dev/null \
		| fgrep -A 1 '<key>mount-point</key>' \
		| tail -1 \
		| sed 's#</string>.*##g ; s#.*<string>##g')


if [ -e "$INSTALL_TO" ]
then

		# move installed version to trash
	mv -vf "$INSTALL_TO" "$HOME/.Trash/$INSTALL_TO:t:r.$INSTALLED_VERSION.app"
fi

echo "$NAME: Installing $FILENAME to $INSTALL_TO"

ditto --noqtn "$MNTPNT/M4VGear.app" "$INSTALL_TO"


EXIT="$?"

if [ "$EXIT" = "0" ]
then

	echo "$NAME: Installation successful"

else
	echo "$NAME: ditto failed (\$EXIT = $EXIT)"

	exit 1
fi


if (( $+commands[unmount.sh] ))
then

	unmount.sh "$MNTPNT"

else
	diskutil eject "$MNTPNT"

fi

exit 0
#EOF
