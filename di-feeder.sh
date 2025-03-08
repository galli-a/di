#!/usr/bin/env zsh -f
# Purpose: 	Download and install latest version of Feeder 4 from <https://reinventedsoftware.com/feeder/>
#
# From:		Tj Luo.ma
# Mail:		luomat at gmail dot com
# Web: 		http://RhymesWithDiploma.com
# Date:		2015-10-26; 2021-05-11 updated for version 4
# Verified:	2025-02-24

NAME="$0:t:r"

[[ -e "$HOME/.path" ]] && source "$HOME/.path"

[[ -e "$HOME/.config/di/defaults.sh" ]] && source "$HOME/.config/di/defaults.sh"

INSTALL_TO="${INSTALL_DIR_ALTERNATE-/Applications}/Feeder.app"

HOMEPAGE="https://reinventedsoftware.com/feeder"

DOWNLOAD_PAGE="https://reinventedsoftware.com/feeder/downloads/"

SUMMARY="Create edit and publish RSS and podcast feeds."

XML_FEED="https://reinventedsoftware.com/feeder/downloads/Feeder4.xml"

INFO=$(curl -sfLS "$XML_FEED" | awk '/<item>/{i++}i==1' | tr '\012' ' ' | tr -s ' |\t')

RELEASE_NOTES_URL=$(echo "$INFO" | sed 's#.*<sparkle:releaseNotesLink>##g ; s#</sparkle:releaseNotesLink>.*##g')

LATEST_BUILD=$(echo "$INFO" | sed 's#.*<sparkle:version>##g ; s#</sparkle:version>.*##g')

LATEST_VERSION=$(echo "$INFO" | sed 's#.*<sparkle:shortVersionString>##g ; s#</sparkle:shortVersionString>.*##g')

URL=$(echo "$INFO" | sed 's#.*<enclosure url="##g ; s#" .*##g')

	# If any of these are blank, we should not continue
if [ "$INFO" = "" -o "$LATEST_BUILD" = "" -o "$URL" = "" -o "$LATEST_VERSION" = "" ]
then
	echo "$NAME: Error: bad data received:
	INFO: $INFO
	LATEST_VERSION: $LATEST_VERSION
 	LATEST_BUILD: $LATEST_BUILD
	URL: $URL
	"

	exit 1
fi

if [[ -e "$INSTALL_TO" ]]
then

	INSTALLED_VERSION=`defaults read "$INSTALL_TO/Contents/Info"  CFBundleShortVersionString 2>/dev/null || echo '0'`

	INSTALLED_BUILD=`defaults read "$INSTALL_TO/Contents/Info"  CFBundleVersion 2>/dev/null || echo '0'`

	if [ "$LATEST_BUILD" = "$INSTALLED_BUILD" -a "$LATEST_VERSION" = "$INSTALLED_VERSION" ]
	then
		echo "$NAME: Up-To-Date ($INSTALLED_VERSION/$INSTALLED_BUILD)"
		exit 0
	fi

	echo "$NAME: Mis-match: Installed = $INSTALLED_VERSION/$INSTALLED_BUILD vs Latest = $LATEST_VERSION/$LATEST_BUILD"

	autoload is-at-least

	is-at-least "$LATEST_BUILD" "$INSTALLED_BUILD"

	if [ "$?" = "0" ]
	then
		echo "$NAME: Installed version (Build: $INSTALLED_BUILD) is ahead of official version (Build: $LATEST_BUILD)"
		exit 0
	fi

	if [[ -e "$INSTALL_TO/Contents/_MASReceipt/receipt" ]]
	then
		echo "$NAME: $INSTALL_TO was installed from the Mac App Store and cannot be updated by this script."
		echo "	See <https://apps.apple.com/us/app/feeder-3/id1043616031?mt=12> or"
		echo "	<macappstore://apps.apple.com/us/app/feeder-3/id1043616031>"
		echo "	Please use the App Store app to update it: <macappstore://showUpdatesPage?scan=true>"
		exit 0
	fi

fi

FILENAME="${DOWNLOAD_DIR_ALTERNATE-$HOME/Downloads}/${${INSTALL_TO:t:r}// /}-${${LATEST_VERSION}// /}_${${LATEST_BUILD}// /}.dmg"

if (( $+commands[lynx] ))
then

	 ( echo -n "$NAME: Release Notes for $INSTALL_TO:t:r Version $LATEST_VERSION / $LATEST_BUILD: " ;
		curl -sfL "$RELEASE_NOTES_URL" \
		| sed '1,/<h2>/d; /<h2>/,$d' \
		| lynx -dump -nomargins -width=10000 -assume_charset=UTF-8 -pseudo_inlines  -stdin ;
		echo "Source: <$RELEASE_NOTES_URL>" ) | tee "$FILENAME:r.txt"
fi

echo "$NAME: Downloading '$URL' to '$FILENAME':"

	# Download it
curl --continue-at - --fail --location --referer ";auto" --output "${FILENAME}" "$URL"

EXIT="$?"

	## exit 22 means 'the file was already fully downloaded'
[ "$EXIT" != "0" -a "$EXIT" != "22" ] && echo "$NAME: Download of $URL failed (EXIT = $EXIT)" && exit 0

[[ ! -e "$FILENAME" ]] && echo "$NAME: $FILENAME does not exist." && exit 0

[[ ! -s "$FILENAME" ]] && echo "$NAME: $FILENAME is zero bytes." && rm -f "$FILENAME" && exit 0

	# Mount the DMG
MNTPNT=$(hdiutil attach -nobrowse -plist "$FILENAME" 2>/dev/null \
		| fgrep -A 1 '<key>mount-point</key>' \
		| tail -1 \
		| sed 's#</string>.*##g ; s#.*<string>##g')

if [[ "$MNTPNT" == "" ]]
then
	echo "$NAME: MNTPNT is empty"
	exit 0
fi

	# Move the old version (if any) to trash
if [ -e "$INSTALL_TO" ]
then
	mv -vf "$INSTALL_TO" "$HOME/.Trash/$INSTALL_TO:t:r.${INSTALLED_VERSION}.${INSTALLED_BUILD}.$RANDOM.app"
fi

echo "$NAME: Installing $MNTPNT/$INSTALL_TO:t to $INSTALL_TO..."

	# Install it
ditto -v --noqtn "$MNTPNT/$INSTALL_TO:t" "$INSTALL_TO"

EXIT="$?"

if [ "$EXIT" = "0" ]
then

	echo "$NAME: Successfully updated/installed $INSTALL_TO"

else
	echo "$NAME: 'ditto' failed (\$EXIT = $EXIT)"

	exit 1
fi


	# Eject the DMG
if (( $+commands[unmount.sh] ))
then
	unmount.sh "$MNTPNT"
else
	diskutil eject "$MNTPNT"
fi


exit 0
#
#EOF
