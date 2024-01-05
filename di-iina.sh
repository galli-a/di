#!/usr/bin/env zsh -f
# Purpose: Download and install the latest version of IINA from iina.io
#
# From:	Timothy J. Luoma
# Mail:	luomat at gmail dot com
# Date:	2019-04-02

NAME="$0:t:r"

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
fi


INSTALL_TO='/Applications/IINA.app'

XML_FEED='https://www.iina.io/appcast.xml'

INFO=("$(curl -sfLS "$XML_FEED" \
	| tr -s '\n| |\t' ' ' \
  	| sed -e 's#\s*<item>#TKTKTK#g' \
  	| sed -e 's#</item>##g' \
 	| sed -e 's#TKTKTK#\n#g' \
 	| egrep '<pubDate>' \
  	| head -n 1 \
 	| tr -s ' ' '\n')")

# echo $INFO

LATEST_VERSION=$(echo "$INFO" \
	| egrep '<sparkle:shortVersionString>' \
	| sed -e 's#<sparkle:shortVersionString>##' \
	| sed -e 's#</sparkle:shortVersionString>##')
LATEST_BUILD=$(echo "$INFO" \
	| egrep '<sparkle:version>' \
	| sed -e 's#<sparkle:version>##' \
	| sed -e 's#</sparkle:version>##')
URL=$(echo "$INFO" \
	| egrep 'url' \
	| egrep -v 'delta' \
	| sed -e 's#url="##' \
	| sed -e 's#"##')
RELEASE_NOTES_URL=$(echo "$INFO" \
	| egrep '<sparkle:releaseNotesLink>' \
	| sed -e 's#<sparkle:releaseNotesLink>##' \
	| sed -e 's#</sparkle:releaseNotesLink>##')

# echo $LATEST_BUILD
# echo $LATEST_VERSION
# echo $URL
# echo $RELEASE_NOTES_URL

	# If any of these are blank, we cannot continue
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

	(lynx -dump -nomargins -width='10000' -assume_charset=UTF-8 -pseudo_inlines -nonumbers -nolist "$RELEASE_NOTES_URL" ; \
	 echo "\n\nSource: $RELEASE_NOTES_URL") \
	| tee "$FILENAME:r.txt"

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
