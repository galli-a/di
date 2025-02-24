#!/usr/bin/env zsh -f
# Purpose: 	Download and install the latest version of Screens Connect
#
# From:		Timothy J. Luoma
# Mail:		luomat at gmail dot com
# Date:		2018-07-17
# Verified:	2025-02-23

NAME="$0:t:r"

INSTALL_TO='/Applications/Screens Connect.app'

HOMEPAGE="http://screensconnect.com/en/"

DOWNLOAD_PAGE="https://edovia.com/screens-connect/"

SUMMARY="Screens Connect is a free utility that lets you connect back to your Mac or Windows PC from anywhere in the world."

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
fi

XML_FEED="https://updates.edovia.com/com.edovia.screens.connect.mac/appcast.xml"

TEMPFILE="${TMPDIR-/tmp}/${NAME}.${TIME}.$$.$RANDOM.xml"

curl -sfL "$XML_FEED" >| "$TEMPFILE"

URL=$(tr '"' '\012' < "$TEMPFILE" | egrep -i '^https.*screensconnect.*\.zip$' | head -1)

LATEST_BUILD=$(tr ' ' '\012' < "$TEMPFILE" | egrep -i '^sparkle:version=' | head -1 | tr -dc '[0-9]')

LATEST_VERSION=$(tr ' ' '\012' < "$TEMPFILE" | egrep -i '^sparkle:shortVersionString=' | head -1 | tr -dc '[0-9]\.')

	# If any of these are blank, we should not continue
if [ "$LATEST_BUILD" = "" -o "$URL" = "" -o "$LATEST_VERSION" = "" ]
then
	echo "$NAME: Error: bad data received:
	LATEST_VERSION: $LATEST_VERSION
	LATEST_BUILD: $LATEST_BUILD
	URL: $URL
	"

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

else

	FIRST_INSTALL='yes'
fi

FILENAME="$HOME/Downloads/ScreensConnect-${LATEST_VERSION}_${LATEST_BUILD}.zip"

if (( $+commands[lynx] ))
then

	RELEASE_NOTES=$(sed '1,/CDATA\[/d; /\]\]\>/,$d' "$TEMPFILE" \
				| lynx -dump -nomargins -width='10000' -assume_charset=UTF-8 -pseudo_inlines -stdin)

	echo "$RELEASE_NOTES\n\nURL: $URL" | tee "$FILENAME:r.txt"

fi

echo "$NAME: Downloading '$URL' to '$FILENAME':"

curl --continue-at - --fail --location --output "$FILENAME" "$URL"

EXIT="$?"

	## exit 22 means 'the file was already fully downloaded'
[ "$EXIT" != "0" -a "$EXIT" != "22" ] && echo "$NAME: Download of $URL failed (EXIT = $EXIT)" && exit 0

[[ ! -e "$FILENAME" ]] && echo "$NAME: $FILENAME does not exist." && exit 0

[[ ! -s "$FILENAME" ]] && echo "$NAME: $FILENAME is zero bytes." && rm -f "$FILENAME" && exit 0

UNZIP_TO=$(mktemp -d "${TMPDIR-/tmp/}${NAME}-XXXXXXXX")

echo "$NAME: Unzipping '$FILENAME' to '$UNZIP_TO':"

ditto -xk --noqtn "$FILENAME" "$UNZIP_TO"

EXIT="$?"

if [[ "$EXIT" == "0" ]]
then
	echo "$NAME: Unzip successful"
else
		# failed
	echo "$NAME failed (ditto -xkv '$FILENAME' '$UNZIP_TO')"

	exit 1
fi

if [[ -e "$INSTALL_TO" ]]
then

	pgrep -xq "$INSTALL_TO:t:r" \
	&& LAUNCH='yes' \
	&& osascript -e "tell application \"$INSTALL_TO:t:r\" to quit"

		# move installed version to trash
	mv -vf "$INSTALL_TO" "$HOME/.Trash/$INSTALL_TO:t:r.$INSTALLED_VERSION.app"

	EXIT="$?"

	if [[ "$EXIT" != "0" ]]
	then
		echo "$NAME: failed to move existing $INSTALL_TO to $HOME/.Trash/"
		exit 1
	fi
fi

echo "$NAME: Moving new version of '$INSTALL_TO:t' (from '$UNZIP_TO') to '$INSTALL_TO'."

	# Move the file out of the folder
mv -vn "$UNZIP_TO/$INSTALL_TO:t" "$INSTALL_TO"

EXIT="$?"

if [[ "$EXIT" = "0" ]]
then

	echo "$NAME: Successfully installed '$UNZIP_TO/$INSTALL_TO:t' to '$INSTALL_TO'."

else
	echo "$NAME: Failed to move '$UNZIP_TO/$INSTALL_TO:t' to '$INSTALL_TO'."

	exit 1
fi

[[ "$LAUNCH" = "yes" ]] && open -a "$INSTALL_TO"

exit 0
#
#EOF

