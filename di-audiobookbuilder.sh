#!/usr/bin/env zsh -f
# Purpose: 	Download and install latest version of AudioBook Builder from http://www.splasm.com/audiobookbuilder/
#
# From:		Timothy J. Luoma
# Mail:		luomat at gmail dot com
# Date:		2015-12-09
# Verified:	2025-02-18

NAME="$0:t:r"

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
fi

HOMEPAGE="http://www.splasm.com/audiobookbuilder/"

DOWNLOAD_PAGE="http://www.splasm.com/downloads/audiobookbuilder/Audiobook%20Builder.dmg"

SUMMARY="Audiobook Builder makes it easy to turn your audio CDs and files into audiobooks for your iPhone, iPod or iPad. Join audio, create enhanced chapter stops, adjust quality settings and let Audiobook Builder handle the rest. When it finishes you get one or a few audiobook tracks in iTunes instead of hundreds or even thousands of music tracks!"

	## Since the XML_FEED doesn't specify an enclosure url, I assume this
	## will always point to the latest version
URL="http://www.splasm.com/downloads/audiobookbuilder/Audiobook%20Builder.dmg"

	## Where should the app be installed to?
INSTALL_TO='/Applications/Audiobook Builder.app'

	## if installed, get current version. If not, put in 1.0.0
INSTALLED_VERSION=$(defaults read "$INSTALL_TO/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo '2.0')

INSTALLED_BUILD=$(defaults read "$INSTALL_TO/Contents/Info" CFBundleVersion 2>/dev/null || echo '200')

	## Use installed version in User Agent when requesting Sparkle feed
UA="Audiobook Builder/$INSTALLED_VERSION Sparkle/1.5"

	## This is the feed for version 2
XML_FEED='https://www.splasm.com/versions/audiobookbuilder2x.xml'

	# n.b. there is a beta feed but I'm not sure if it is used often and its format is different
	#XML_FEED='http://www.splasm.com/special/audiobookbuilder/audiobookbuilderprerelease_sparkle.xml'

INFO=$(curl --connect-timeout 10 -sfL -A "$UA" "$XML_FEED" \
		| egrep '(<version>.*</version>|<bundleVersion>.*</bundleVersion>)' \
		| head -2 )

LATEST_VERSION=$(echo "$INFO" | egrep '<version>.*</version>' | tr -dc '[0-9]\.')

LATEST_BUILD=$(echo "$INFO" | egrep '<bundleVersion>.*</bundleVersion>' | tr -dc '[0-9]\.')

## 2020-12-18 - Old code moved to bottom of script. $INFO / $LATEST_VERSION / $LATEST_BUILD all better defined

if [[ -e "$INSTALL_TO" ]]
then

	INSTALLED_VERSION=$(defaults read "${INSTALL_TO}/Contents/Info" CFBundleShortVersionString)

	INSTALLED_BUILD=$(defaults read "${INSTALL_TO}/Contents/Info" CFBundleVersion)

	autoload is-at-least

	is-at-least "$LATEST_VERSION" "$INSTALLED_VERSION"

	VERSION_COMPARE="$?"

	is-at-least "$LATEST_BUILD" "$INSTALLED_BUILD"

	BUILD_COMPARE="$?"

	if [ "$VERSION_COMPARE" = "0" -a "$BUILD_COMPARE" = "0" ]
	then
		echo "$NAME: Up-To-Date ($INSTALLED_VERSION/$INSTALLED_BUILD)"
		exit 0
	fi

		## If we get here, we need to update
	echo "$NAME: Outdated: $INSTALLED_VERSION/$INSTALLED_BUILD vs $LATEST_VERSION/$LATEST_BUILD"

	if [[ -e "$INSTALL_TO/Contents/_MASReceipt/receipt" ]]
	then
		echo "$NAME: $INSTALL_TO was installed from the Mac App Store and cannot be updated by this script."
		echo "	See <https://apps.apple.com/us/app/audiobook-builder/id406226796?mt=12> or"
		echo "	<macappstore://apps.apple.com/us/app/audiobook-builder/id406226796>"
		echo "	Please use the App Store app to update it: <macappstore://showUpdatesPage?scan=true>"
		exit 0
	fi

	FIRST_INSTALL='no'

	if [[ ! -w "$INSTALL_TO" ]]
	then
		echo "$NAME: '$INSTALL_TO' exists, but you do not have 'write' access to it, therefore you cannot update it." >>/dev/stderr

		exit 2
	fi

else

	FIRST_INSTALL='yes'
fi

	## Save the DMG but put the version number in the filename
	## so I'll know what version it is later
FILENAME="$HOME/Downloads/AudioBookBuilder-${LATEST_VERSION}_${LATEST_BUILD}.dmg"

if (( $+commands[lynx] ))
then

	RELEASE_NOTES_URL="$XML_FEED"

	( echo "$NAME: Release Notes for $INSTALL_TO:t:r version $LATEST_VERSION / $LATEST_BUILD:" ;
		curl -sfL "$RELEASE_NOTES_URL" \
		| sed '1,/<message>/d; /<\/message>/,$d ; s#\]\]\>##g ; s#<\!\[CDATA\[##g' \
		| lynx -dump -nomargins -width=10000 -assume_charset=UTF-8 -pseudo_inlines -stdin ;
		echo "\nSource: XML_FEED: <$XML_FEED>" ) | tee "$FILENAME:r.txt"
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
else
	echo "$NAME: MNTPNT is $MNTPNT"
fi

if [[ -e "$INSTALL_TO" ]]
then
		# Quit app, if running
	pgrep -xq "$INSTALL_TO:t:r" \
	&& LAUNCH='yes' \
	&& osascript -e "tell application \"$INSTALL_TO:t:r\" to quit"

		# move installed version to trash
	mv -vf "$INSTALL_TO" "$HOME/.Trash/$INSTALL_TO:t:r.${INSTALLED_VERSION}_${INSTALLED_BUILD}.app"
fi

echo "$NAME: Installing '$MNTPNT/$INSTALL_TO:t' to '$INSTALL_TO': "

ditto --noqtn -v "$MNTPNT/$INSTALL_TO:t" "$INSTALL_TO"

EXIT="$?"

if [[ "$EXIT" == "0" ]]
then
	echo "$NAME: Successfully installed $INSTALL_TO"
else
	echo "$NAME: ditto failed"

	exit 1
fi

[[ "$LAUNCH" = "yes" ]] && open -a "$INSTALL_TO"

echo -n "$NAME: Unmounting $MNTPNT: " && diskutil eject "$MNTPNT"

exit 0
#EOF
