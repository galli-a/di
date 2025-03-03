#!/usr/bin/env zsh -f
# Purpose: 	Download and install the latest version of Karabiner-Elements from <https://pqrs.org/osx/karabiner/>
#
# From:		Timothy J. Luoma
# Mail:		luomat at gmail dot com
# Date:		2018-08-11
# Verified:	2025-03-03

NAME="$0:t:r"

	# It doesn't really matter which one we check,
	# they both have the same version information
	#INSTALL_TO="/Applications/Karabiner-EventViewer.app"
INSTALL_TO="/Applications/Karabiner-Elements.app"

HOMEPAGE="https://pqrs.org/osx/karabiner/"

DOWNLOAD_PAGE="https://pqrs.org/osx/karabiner/"

SUMMARY="A powerful and stable keyboard customizer for macOS."

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
fi

XML_FEED='https://appcast.pqrs.org/karabiner-elements-appcast.xml'

INFO=$(curl -sfLS "$XML_FEED" | awk '/<item>/{i++}i==1' | tr '\012' ' ')

URL=$(echo "$INFO" | sed 's#.*enclosure url="##g ; s#" .*##g')

LATEST_VERSION=$(echo "$INFO" | sed 's#.*sparkle:version="##g ; s#".*##g')

	# If any of these are blank, we cannot continue
if [ "$INFO" = "" -o "$URL" = "" -o "$LATEST_VERSION" = "" ]
then
	echo "$NAME: Error: bad data received:
	INFO: $INFO
	LATEST_VERSION: $LATEST_VERSION
	URL: $URL
	"  >>/dev/stderr

	exit 1
fi

PUB_DATE=$(echo "$INFO" | sed -e 's#.*<pubDate>##g' -e 's#</pubDate>.*##g')

HTML_RELEASE_NOTES=$(echo "$INFO" | sed -e 's#.*<!\[CDATA\[##g' -e 's#\]\]\>.*##g')

MORE_URL='https://karabiner-elements.pqrs.org/docs/releasenotes/'

if [[ -e "$INSTALL_TO" ]]
then

	INSTALLED_VERSION=$(defaults read "${INSTALL_TO}/Contents/Info" CFBundleShortVersionString)

	autoload is-at-least

	is-at-least "$LATEST_VERSION" "$INSTALLED_VERSION"

	VERSION_COMPARE="$?"

	if [ "$VERSION_COMPARE" = "0" ]
	then
		echo "$NAME: Up-To-Date ($INSTALLED_VERSION vs $LATEST_VERSION)"
		exit 0
	fi

	echo "$NAME: Outdated: $INSTALLED_VERSION vs $LATEST_VERSION"

	FIRST_INSTALL='no'

else

	FIRST_INSTALL='yes'
fi

FILENAME="$HOME/Downloads/$INSTALL_TO:t:r-${LATEST_VERSION}.dmg"

if [[ "$HTML_RELEASE_NOTES" != "" ]]
then
	if (( $+commands[lynx] ))
	then

		RELEASE_NOTES=$(echo "$HTML_RELEASE_NOTES" \
		| lynx -dump -width='10000' -display_charset=UTF-8 -assume_charset=UTF-8 -pseudo_inlines -stdin -nolist -nomargins -nonumbers)

		echo "$NAME: Release Notes for $INSTALL_TO:t:r ($LATEST_VERSION):\n\nDate: ${PUB_DATE}\n\n${RELEASE_NOTES}\n${MORE_URL}" \
		| tee "$FILENAME:r.txt"
	fi
fi

echo "$NAME: Downloading '$URL' to '$FILENAME':"

curl --continue-at - --fail --location --output "$FILENAME" "$URL"

EXIT="$?"

	## exit 22 means 'the file was already fully downloaded'
[ "$EXIT" != "0" -a "$EXIT" != "22" ] && echo "$NAME: Download of $URL failed (EXIT = $EXIT)" && exit 0

[[ ! -e "$FILENAME" ]] && echo "$NAME: $FILENAME does not exist." && exit 0

[[ ! -s "$FILENAME" ]] && echo "$NAME: $FILENAME is zero bytes." && rm -f "$FILENAME" && exit 0

echo "$NAME: Mounting $FILENAME:"

MNTPNT=$(hdiutil attach -nobrowse -plist "$FILENAME" 2>/dev/null \
	| fgrep -A 1 '<key>mount-point</key>' \
	| tail -1 \
	| sed 's#</string>.*##g ; s#.*<string>##g')

if [[ "$MNTPNT" == "" ]]
then
	echo "$NAME: MNTPNT is empty"
	exit 1
fi

PKG=$(find "$MNTPNT" -maxdepth 2 -iname \*.pkg -print)

if [[ "$PKG" == "" ]]
then
	echo "$NAME: Failed to find a .pkg file in $MNTPNT"
	exit 1
fi

if (( $+commands[pkginstall.sh] ))
then
	pkginstall.sh "$PKG"
else
	sudo /usr/sbin/installer -verbose -pkg "$PKG" -dumplog -target / -lang en 2>&1
fi

EXIT="$?"

if [ "$EXIT" != "0" ]
then

	echo "$NAME: installation of $PKG failed (\$EXIT = $EXIT)."

		# Show the .pkg file at least, to draw their attention to it.
	open -R "$PKG"

	exit 1
fi

echo "$NAME: Unmounting $MNTPNT:"

diskutil eject "$MNTPNT"

if (( $+commands[tag-karabiner.sh] ))
then

		## This is a separate script I need to run after updates happen
		## with specific changes for how I use macOS so I don't include them here

	tag-karabiner.sh

fi

exit 0
#EOF
