#!/usr/bin/env zsh -f
# Purpose: 	Download and install the latest version of Keymou
#
# From:		Timothy J. Luoma
# Mail:		luomat at gmail dot com
# Date:		2016-05-22
# Verified:	2025-02-24

NAME="$0:t:r"

INSTALL_TO='/Applications/Keymou.app'

HOMEPAGE="https://manytricks.com/keymou/"

DOWNLOAD_PAGE="https://manytricks.com/download/keymou"

SUMMARY="Sometimes using the keyboard is just more convenient than a mouse or trackpad: Keymou gives you full control over your mouse pointer via keyboard shortcuts."

XML_FEED='https://manytricks.com/keymou/appcast.xml'

RELEASE_NOTES_URL='https://manytricks.com/keymou/releasenotes/'

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
fi

INSTALLED_VERSION=`defaults read "$INSTALL_TO/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo '0'`

INFO=($(curl -sfL "$XML_FEED" \
		| tr -s ' ' '\012' \
		| egrep 'sparkle:version=|sparkle:shortVersionString=|url=' \
		| head -3 \
		| sort \
		| awk -F'"' '/^/{print $2}'))

LATEST_VERSION="$INFO[1]"
LATEST_BUILD="$INFO[2]"
URL="$INFO[3]"

	# If any of these are blank, we should not continue
if [ "$INFO" = "" -o "$LATEST_VERSION" = "" -o "$LATEST_BUILD" = "" -o "$URL" = "" ]
then
	echo "$NAME: Error: bad data received:\nINFO: $INFO\nLATEST_VERSION: $LATEST_VERSION\nLATEST_BUILD: $LATEST_BUILD\nURL: $URL"
	exit 1
fi

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

	echo "$NAME: Outdated: $INSTALLED_VERSION/$INSTALLED_BUILD vs $LATEST_VERSION/$LATEST_BUILD"

	FIRST_INSTALL='no'

	if [[ -e "$INSTALL_TO/Contents/_MASReceipt/receipt" ]]
	then
		echo "$NAME: $INSTALL_TO was installed from the Mac App Store and cannot be updated by this script."
		echo "	See <https://apps.apple.com/us/app/keymou/id449863619?mt=12> or"
		echo "	<macappstore://apps.apple.com/us/app/keymou/id449863619>"
		echo "	Please use the App Store app to update it: <macappstore://showUpdatesPage?scan=true>"
		exit 0
	fi

else

	FIRST_INSTALL='yes'
fi

FILENAME="$HOME/Downloads/$INSTALL_TO:t:r-${LATEST_VERSION}_${LATEST_BUILD}.dmg"

if (( $+commands[lynx] ))
then

	( curl -sfLS "$RELEASE_NOTES_URL" \
	| sed '1,/BODY STARTS HERE/d' \
	| awk '/<h2>/{i++}i==1' \
	| lynx -dump -nomargins -width='10000' -assume_charset=UTF-8 -pseudo_inlines -stdin ;
	echo "\nSource: <$RELEASE_NOTES_URL>" ) | tee "$FILENAME:r.txt"

fi

echo "$NAME: Downloading '$URL' to '$FILENAME':"

curl --continue-at - --fail --location --output "$FILENAME" "$URL"

EXIT="$?"

	## exit 22 means 'the file was already fully downloaded'
[ "$EXIT" != "0" -a "$EXIT" != "22" ] && echo "$NAME: Download of $URL failed (EXIT = $EXIT)" && exit 0

[[ ! -e "$FILENAME" ]] && echo "$NAME: $FILENAME does not exist." && exit 0

[[ ! -s "$FILENAME" ]] && echo "$NAME: $FILENAME is zero bytes." && rm -f "$FILENAME" && exit 0

if [ -e "$INSTALL_TO" ]
then
		# Quit app, if running
	pgrep -xq "$INSTALL_TO:t:r" \
	&& LAUNCH='yes' \
	&& osascript -e "tell application \"$INSTALL_TO:t:r\" to quit"

		# move installed version to trash
	mv -vf "$INSTALL_TO" "$HOME/.Trash/$INSTALL_TO:t:r.$INSTALLED_VERSION.app"
fi

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

echo "$NAME: Unmounting $MNTPNT:"

diskutil eject "$MNTPNT"

exit 0
#EOF
