#!/usr/bin/env zsh -f
# Purpose: 	Download and install the latest version of Witch from <https://manytricks.com/witch/>
#
# From:		Timothy J. Luoma
# Mail:		luomat at gmail dot com
# Date:		2016-05-22
# Verified:	2025-02-22

NAME="$0:t:r"

if [ -e "/Library/PreferencePanes/Witch.prefPane" -a -e "$HOME/Library/PreferencePanes/Witch.prefPane" ]
then

	echo "$NAME: Witch.prefPane is installed at _BOTH_ '/Library/PreferencePanes/Witch.prefPane' and '$HOME/Library/PreferencePanes/Witch.prefPane'.
	Please remove one."

	exit 1

elif [[ -e "/Library/PreferencePanes/Witch.prefPane" ]]
then

	INSTALL_TO="/Library/PreferencePanes/Witch.prefPane"

else

	INSTALL_TO="$HOME/Library/PreferencePanes/Witch.prefPane"

fi

XML_FEED='https://manytricks.com/witch/appcast.xml'

HOMEPAGE="https://manytricks.com/witch/"

DOWNLOAD_PAGE="https://manytricks.com/download/witch"

SUMMARY="The built-in macOS app switcher is great if all you use are one-window applications. But you probably have many windows open in many apps, possibly with many tabs, and navigating them all is a pain. Enter Witch, with which you can switch everything.."

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
fi

INFO=($(curl -sfL "$XML_FEED" \
		| tr -s ' ' '\012' \
		| egrep 'sparkle:shortVersionString|sparkle:version=|url=' \
		| head -3 \
		| sort \
		| awk -F'"' '/^/{print $2}'))

	# "Sparkle" will always come before "url" because of "sort"
LATEST_VERSION="$INFO[1]"
LATEST_BUILD="$INFO[2]"
URL="$INFO[3]"

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

FILENAME="$HOME/Downloads/$INSTALL_TO:t:r-${LATEST_VERSION}_${LATEST_BUILD}.dmg"

if (( $+commands[lynx] ))
then

	RELEASE_NOTES_URL=$(curl -sfL "$XML_FEED" \
		| fgrep '<sparkle:releaseNotesLink>' \
		| head -1 \
		| sed 's#.*<sparkle:releaseNotesLink>##g ; s#</sparkle:releaseNotesLink>##g')

	( echo -n "$NAME: Release Notes for " ;
		(curl -sfL "$RELEASE_NOTES_URL" \
		 | sed '1,/paidupgradenote/d; /<\/ul>/,$d' ; echo '</ul>' ) \
		| lynx -dump -nomargins -width='10000' -assume_charset=UTF-8 -pseudo_inlines -stdin;
	echo "\nSource: <$RELEASE_NOTES_URL>") | tee "$FILENAME:r.txt"

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
	pgrep -xq "witchdaemon" \
	&& LAUNCH='yes' \
	&& osascript -e 'tell application "witchdaemon" to quit'

		# move installed version to trash
	mv -vf "$INSTALL_TO" "$HOME/.Trash/$INSTALL_TO:t:r.${INSTALLED_VERSION}_${INSTALLED_BUILD}.${RANDOM}.app"
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

if [[ "$LAUNCH" = "yes" ]]
then
		# Either of these _should_ work. Hopefully one of them actually will.
	osascript -e 'tell application "witchdaemon" to activate'

	open -a "$INSTALL_TO/Contents/Helpers/witchdaemon.app"
fi

	# This will open the PreferencePane, which will immediately tell you to open the Accessibility Pane.
	# but I'm not sure what else to do. Seems like the sort of app you'd actually want to launch
	# on first install.
[[ "$FIRST_INSTALL" = 'yes' ]] && open "$INSTALL_TO"

exit 0
#EOF
