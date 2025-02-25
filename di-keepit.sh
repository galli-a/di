#!/usr/bin/env zsh -f
# Purpose: Download and install latest version of Keep It from <https://reinventedsoftware.com/keepit/>
#
# From:	Timothy J. Luoma
# Mail:	luomat at gmail dot com
# Date:	2018-08-23

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
fi

NAME="$0:t:r"

INSTALL_TO="/Applications/Keep It.app"

HOMEPAGE="https://reinventedsoftware.com/keepit/"

DOWNLOAD_PAGE="https://reinventedsoftware.com/keepit/downloads/"

SUMMARY="Keep It is a notebook, scrapbook and organizer, ideal for writing notes, keeping web links, storing documents, images or any kind of file, and finding them again. Available on Mac, and as a separate app for iPhone and iPad, Keep It is the destination for all those things you want to put somewhere, confident you will find them again later."

##	This was for version 1
# XML_FEED='https://reinventedsoftware.com/keepit/downloads/keepit.xml'

XML_FEED='https://reinventedsoftware.com/keepit/downloads/keepit2.xml'

ITUNES_URL='apps.apple.com/us/app/keep-it/id1272768911'

INFO=$(curl -sfLS "$XML_FEED" | awk '/<item>/{i++}i==1' | tr -s '\012' ' ')

URL=$(echo "$INFO" | sed 's#.*enclosure url="##g ; s#" .*##g')

RELEASE_NOTES_URL=$(echo "$INFO" | sed 's#.*<sparkle:releaseNotesLink>##g ; s#</sparkle:releaseNotesLink>.*##g')

LATEST_VERSION=$(echo "$INFO" | sed 's#.*<sparkle:shortVersionString>##g ; s#</sparkle:shortVersionString>.*##g')

LATEST_BUILD=$(echo "$INFO" | sed 's#.*<sparkle:version>##g ; s#</sparkle:version>.*##g' )

	# If any of these are blank, we should not continue
if [ "$INFO" = "" -o "$URL" = "" -o "$LATEST_VERSION" = "" ]
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

	INSTALLED_VERSION=$(defaults read "${INSTALL_TO}/Contents/Info" CFBundleShortVersionString)

	autoload is-at-least

	is-at-least "$LATEST_VERSION" "$INSTALLED_VERSION"

	VERSION_COMPARE="$?"

	if [ "$VERSION_COMPARE" = "0" ]
	then
		echo "$NAME: Up-To-Date ($INSTALLED_VERSION)"
		exit 0
	fi

	echo "$NAME: Outdated: $INSTALLED_VERSION vs $LATEST_VERSION"

	FIRST_INSTALL='no'

	if [[ -e "$INSTALL_TO/Contents/_MASReceipt/receipt" ]]
	then
		echo "$NAME: $INSTALL_TO was installed from the Mac App Store and cannot be updated by this script."

		if [[ "$ITUNES_URL" != "" ]]
		then
			echo "	See <https://$ITUNES_URL?mt=12> or"
			echo "	<macappstore://$ITUNES_URL>"
		fi

		echo "	Please use the App Store app to update it: <macappstore://showUpdatesPage?scan=true>"
		exit 0
	fi

else

	FIRST_INSTALL='yes'
fi

FILENAME="$HOME/Downloads/KeepIt-${LATEST_VERSION}.dmg"

if (( $+commands[lynx] ))
then

	( echo -n "$NAME: Release Notes for $INSTALL_TO:t:r " ; \
		(curl -sfLS "$RELEASE_NOTES_URL" | sed '1,/<body>/d; /<\/ul>/,$d' ; echo '</ul>') \
	    | lynx -dump -nomargins -width='10000' -assume_charset=UTF-8 -pseudo_inlines -stdin \
		&& echo "\nSource: <$RELEASE_NOTES_URL>" \
	) | tee "$FILENAME:r.txt"

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

if [[ -e "$INSTALL_TO" ]]
then
		# Quit app, if running
	pgrep -xq "$INSTALL_TO:t:r" \
	&& LAUNCH='yes' \
	&& osascript -e "tell application \"$INSTALL_TO:t:r\" to quit"

		# move installed version to trash
	mv -vf "$INSTALL_TO" "$HOME/.Trash/$INSTALL_TO:t:r.${INSTALLED_VERSION}.app"
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
