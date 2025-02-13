#!/usr/bin/env zsh -f
# Purpose: Download and install the latest version of Flash
#
# From:	Timothy J. Luoma
# Mail:	luomat at gmail dot com
# Date:	2019-08-18

NAME="$0:t:r"

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
fi

INSTALL_TO='/Library/PreferencePanes/Flash Player.prefPane'

LATEST_VERSION=$(curl -sfLS "https://fpdownload.adobe.com/pub/flashplayer/update/current/xml/version_en_mac_pl.xml" \
				| tr '\012' ' ' \
				| sed 's#.*<update version="##g; s#">.*##g ; s#,#.#g')

if [[ "$LATEST_VERSION" == "" ]]
then
	echo "$NAME: 'LATEST_VERSION' is empty."
	exit 1
fi

URL="https://fpdownload.adobe.com/get/flashplayer/pdc/$LATEST_VERSION/install_flash_player_osx.dmg"

HTTP_RESPONSE=$(curl --head -sfLS "$URL" | awk -F' ' '/^HTTP/{print $2}' | cat -v)

if [[ "$HTTP_RESPONSE" != "200" ]]
then
	echo "$NAME: Found '$LATEST_VERSION' but '$URL' returns '$HTTP_RESPONSE' instead of '200'."
	exit 1
fi

PLIST="$INSTALL_TO/Contents/Info.plist"

if [[ -e "$PLIST" ]]
then
	INSTALLED_VERSION=$(defaults read $PLIST CFBundleVersion)

	autoload is-at-least

	is-at-least "$LATEST_VERSION" "$INSTALLED_VERSION"

	VERSION_COMPARE="$?"

	if [ "$VERSION_COMPARE" = "0" ]
	then
		echo "$NAME: Up-To-Date ($INSTALLED_VERSION)"
		exit 0
	fi

	echo "$NAME: Outdated: $INSTALLED_VERSION vs $LATEST_VERSION"

fi

FILENAME="$HOME/Downloads/FlashPlayer-${LATEST_VERSION}.dmg"

LOG="$FILENAME:r.log"

echo "$NAME: Downloading '$URL' to '$FILENAME':" | tee -a "$LOG"

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

PKG=$(find "$MNTPNT" -type f -iname 'Adobe Flash Player.pkg' -print 2>/dev/null)

if [[ "$PKG" == "" ]]
then
	echo "$NAME: Failed to find 'Adobe Flash Player.pkg' in '$MNTPNT'."
	exit 1
fi

echo "$NAME: Installing '$PKG' from '$FILENAME'...\n" | tee -a "$LOG"

if [[ "$EUID" == "0" ]]
then
		# if we are running as root, we don't need `sudo`
	/usr/sbin/installer -pkg "$PKG" -dumplog -target / -lang en 2>&1 | tee -a "$LOG"
else
	sudo /usr/sbin/installer -pkg "$PKG" -dumplog -target / -lang en 2>&1 | tee -a "$LOG"
fi

EXIT="$?"

if [ "$EXIT" = "0" ]
then
	echo "$NAME: Installation successful" | tee -a "$LOG"
else
	echo "$NAME: installer failed (\$EXIT = $EXIT)" | tee -a "$LOG"
	exit 1
fi

MAX_ATTEMPTS="10"

SECONDS_BETWEEN_ATTEMPTS="1"

	# initialize the counter
COUNT=0

	# NOTE this 'while' loop can be changed to something else
while [[ -e "$MNTPNT" ]]
do

		# increment counter (this is why we init to 0 not 1)
	((COUNT++))

		# check to see if we have exceeded maximum attempts
	if [ "$COUNT" -gt "$MAX_ATTEMPTS" ]
	then
		echo "$NAME: exceeded $MAX_ATTEMPTS to eject '$MNTPNT'. Giving up."
		exit 1
	fi

		# don't sleep the first time through the loop
	[[ "$COUNT" != "1" ]] && sleep ${SECONDS_BETWEEN_ATTEMPTS}

	(echo -n "$NAME: Attempt $COUNT/$MAX_ATTEMPTS at unmounting '$MNTPNT' : " && diskutil eject "$MNTPNT" 2>&1) | tee -a "$LOG"

done

echo "$NAME: Finished"

exit 0
#EOF
