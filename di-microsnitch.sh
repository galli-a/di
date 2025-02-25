#!/usr/bin/env zsh -f
# Purpose: 	Download and install the latest version of Micro Snitch
#
# From:		Timothy J. Luoma
# Mail:		luomat at gmail dot com
# Date:		2019-02-16
# Verified:	2025-02-24

NAME="$0:t:r"

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
fi

INSTALL_TO='/Applications/Micro Snitch.app'

SUMMARY='Ever wondered if an application records audio through your Mac’s built-in microphone without your knowledge? Or if the camera captures video for no good reason?'

PLIST_URL="https://sw-update.obdev.at/update-feeds/microsnitch-1.plist"

zmodload zsh/datetime

TIME=`strftime "%Y-%m-%d--%H.%M.%S" "$EPOCHSECONDS"`

function timestamp { strftime "%Y-%m-%d--%H.%M.%S" "$EPOCHSECONDS" }

TEMPFILE="${TMPDIR-/tmp}/${NAME}.${TIME}.$$.$RANDOM.plist"

curl -sfLS "$PLIST_URL" > "$TEMPFILE"

## DON'T INDENT
INFO=($(cat "$TEMPFILE" \
| tr -d '\t|\n' \
| sed -e 's#</dict><dict>.*##g' -e 's#.*<array><dict>##g' -e 's#</string><key>#\
#g' -e 's#</key><string># #g' -e 's#</string></dict><key>#\
#g' -e 's#</key><dict><key>#\
#g' -e 's#</string>##g' -e 's#<key>##g' \
| sort \
| egrep '^(BundleVersion|BundleShortVersionString|ReleaseNotesURL|DownloadURL) ' \
| awk '{print $NF}'))
## END - DON'T INDENT

LATEST_VERSION="$INFO[1]"

LATEST_BUILD="$INFO[2]"

URL=$(curl -sfLS "https://www.obdev.at/products/microsnitch/download.html" \
	| fgrep .dmg \
	| sed 's#.*https#https#g; s#.dmg.*#.dmg#g')

RELEASE_NOTES_URL="$INFO[4]"

# echo "
# LATEST_VERSION: $LATEST_VERSION
# LATEST_BUILD: $LATEST_BUILD
# URL: $URL
# RELEASE_NOTES_URL: $RELEASE_NOTES_URL
#
# "

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

else

	FIRST_INSTALL='yes'
fi

FILENAME="$HOME/Downloads/${${INSTALL_TO:t:r}// /}-${LATEST_VERSION}_${LATEST_BUILD}.dmg"

if (( $+commands[lynx] ))
then

	lynx -dump -nomargins -width='10000' -assume_charset=UTF-8 -pseudo_inlines "$RELEASE_NOTES_URL" | tee "$FILENAME:r.txt"

fi

echo "$NAME: Downloading '$URL' to '$FILENAME':"

curl --continue-at - --fail --location --output "$FILENAME" "$URL"

EXIT="$?"

	## exit 22 means 'the file was already fully downloaded'
[ "$EXIT" != "0" -a "$EXIT" != "22" ] && echo "$NAME: Download of $URL failed (EXIT = $EXIT)" && exit 0

[[ ! -e "$FILENAME" ]] && echo "$NAME: $FILENAME does not exist." && exit 0

[[ ! -s "$FILENAME" ]] && echo "$NAME: $FILENAME is zero bytes." && rm -f "$FILENAME" && exit 0

echo "\nURL: ${URL}" >>| "$FILENAME:r.txt"

(cd "$FILENAME:h" ; echo "\nLocal sha256:" ; shasum -a 256 "$FILENAME:t" ) >>| "$FILENAME:r.txt"

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

	EXIT="$?"

	if [[ "$EXIT" != "0" ]]
	then

		echo "$NAME: failed to move '$INSTALL_TO' to Trash. ('mv' \$EXIT = $EXIT)"

		exit 1
	fi

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

[[ "$LAUNCH" = "yes" ]] && open -a "$INSTALL_TO"


exit 0
# EOF
