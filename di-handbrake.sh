#!/usr/bin/env zsh -f
# Purpose: download and install HandBrake
#
# From:		Tj Luo.ma
# Mail:		luomat at gmail dot com
# Web: 		http://RhymesWithDiploma.com
# Date:		2018-08-11
# Verified:	2025-02-13 (non beta)

NAME="$0:t:r"

[[ -e "$HOME/.path" ]] && source "$HOME/.path"

[[ -e "$HOME/.config/di/defaults.sh" ]] && source "$HOME/.config/di/defaults.sh"

INSTALL_TO="${INSTALL_DIR_ALTERNATE-/Applications}/HandBrake.app"

HOMEPAGE="https://handbrake.fr"

DOWNLOAD_PAGE="https://handbrake.fr/downloads.php"

SUMMARY="HandBrake is a tool for converting video from nearly any format to a selection of modern, widely supported codecs."

RELEASE_NOTES_URL='https://handbrake.fr/appcast/stable.html'

UA='curl/7.54.0'

	# if you want to install beta releases
	# create a file (empty, if you like) using this file name/path:
PREFERS_BETAS_FILE="$HOME/.config/di/handbrake-prefer-betas.txt"

if [[ -e "$PREFERS_BETAS_FILE" ]]
then

		# This is for betas
	NAME="$NAME (beta releases)"
	BETA='yes'

	URL=$(curl -sfLS "https://github.com/HandBrake/handbrake-snapshots/releases/tag/mac" \
			| tr '"' '\012' \
			| fgrep -i '.dmg' \
			| egrep '^/HandBrake/.*/mac/HandBrake-.*\.dmg' \
			| sed 's#^#https://github.com#g')

	LATEST_VERSION=$(echo "$URL:t:r" | sed 's#HandBrake-##g')

	LATEST_BUILD=""

	FILENAME="$HOME/Downloads/HandBrake-Nightly-${LATEST_VERSION}.dmg"

else
	BETA='no'

	ARCH=$(arch)

	if [[ "$ARCH" == "arm64" ]]
	then
			## Apple Silicon / M1-based Macs
		XML_FEED='https://handbrake.fr/appcast.arm64.xml'
	else
			## Intel-based Macs
		XML_FEED="https://handbrake.fr/appcast.x86_64.xml"
	fi

	INFO=($(curl -A "$UA" -sfL "${XML_FEED}" \
			| tr -s ' ' '\012' \
			| egrep 'sparkle:version|sparkle:shortVersionString|url=' \
			| head -3 \
			| sort \
			| awk -F'"' '/^/{print $2}'))

		# "Sparkle" will always come before "url" because of "sort"
	LATEST_VERSION="$INFO[1]"
	LATEST_BUILD="$INFO[2]"

	# URL=$(echo "$INFO[3]" | sed 's#\&amp;#\&#g')
	# https://download.handbrake.fr/releases/1.2.2/HandBrake-1.2.2.dmg"

	# URL="https://download.handbrake.fr/releases/$LATEST_VERSION/HandBrake-$LATEST_VERSION.dmg"
	URL="https://github.com/HandBrake/HandBrake/releases/download/$LATEST_VERSION/HandBrake-$LATEST_VERSION.dmg"

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

	FILENAME="$HOME/Downloads/$INSTALL_TO:t:r-${LATEST_VERSION}_${LATEST_BUILD}.dmg"
fi

if [[ -e "$INSTALL_TO" ]]
then

	INSTALLED_VERSION=$(defaults read "${INSTALL_TO}/Contents/Info" CFBundleShortVersionString)

	autoload is-at-least

	is-at-least "$LATEST_VERSION" "$INSTALLED_VERSION"

	VERSION_COMPARE="$?"

	if [[ "$LATEST_BUILD" == "" ]]
	then

		if [ "$VERSION_COMPARE" = "0" ]
		then
			echo "$NAME: Up-To-Date ($INSTALLED_VERSION)"
			exit 0
		fi

		echo "$NAME: Outdated: $INSTALLED_VERSION vs $LATEST_VERSION"

	else
		INSTALLED_BUILD=$(defaults read "${INSTALL_TO}/Contents/Info" CFBundleVersion)

		is-at-least "$LATEST_BUILD" "$INSTALLED_BUILD"

		BUILD_COMPARE="$?"

		if [ "$VERSION_COMPARE" = "0" -a "$BUILD_COMPARE" = "0" ]
		then
			echo "$NAME: Up-To-Date ($INSTALLED_VERSION/$INSTALLED_BUILD)"
			exit 0
		fi

		echo "$NAME: Outdated: $INSTALLED_VERSION/$INSTALLED_BUILD vs $LATEST_VERSION/$LATEST_BUILD"
	fi

	FIRST_INSTALL='no'

else

	FIRST_INSTALL='yes'
fi

if [[ "$BETA" == "no" ]]
then
	if (( $+commands[lynx] ))
	then

		RELEASE_NOTES_URL='https://handbrake.fr/appcast/stable.html'

		( echo -n "$NAME: Release Notes for" ;
		lynx -dump -nomargins -width='10000' -assume_charset=UTF-8 -pseudo_inlines "$RELEASE_NOTES_URL" \
		| tr -s '\t' ' ' ;
		echo "\nSource: <$RELEASE_NOTES_URL>" ) \
		| tee "$FILENAME:r.txt"

	fi
else
		# This _is_ a beta / nightly

	(echo "$NAME: No release notes available for nightly builds, but you can see recent changes at:";
	echo "<https://github.com/HandBrake/HandBrake/commits/master>") \
	| tee "$FILENAME:r.txt"

fi

echo "$NAME: Downloading '$URL' to '$FILENAME':"

curl -A "$UA" --continue-at - --fail --location --output "$FILENAME" "$URL"

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

echo "$NAME: Unmounting $MNTPNT:"

diskutil eject "$MNTPNT"

exit 0
#
#EOF
