#!/usr/bin/env zsh -f
# Purpose: 	Download and install the latest version of Suspicious Package from <http://www.mothersruin.com/software/SuspiciousPackage/>
#
# From:		Timothy J. Luoma
# Mail:		luomat at gmail dot com
# Date:		2018-07-19
# Verified:	2025-02-23

NAME="$0:t:r"

[[ -e "$HOME/.path" ]] && source "$HOME/.path"

[[ -e "$HOME/.config/di/defaults.sh" ]] && source "$HOME/.config/di/defaults.sh"

INSTALL_TO="${INSTALL_DIR_ALTERNATE-/Applications}/Suspicious Package.app"

HOMEPAGE="https://www.mothersruin.com/software/SuspiciousPackage/"

DOWNLOAD_PAGE="https://www.mothersruin.com/software/downloads/SuspiciousPackage.dmg"

SUMMARY="An Application for Inspecting macOS Installer Packages."

	# Note the URL is a plist not your ususal RSS/XML file for Sparkle
INFO=$(curl -sfL "http://www.mothersruin.com/software/SuspiciousPackage/data/SuspiciousPackageVersionInfo.plist")

LATEST_VERSION=$(echo "$INFO" | fgrep -A1 "<key>CFBundleShortVersionString</key>" | tr -dc '[0-9]\.')

LATEST_BUILD=$(echo "$INFO" | fgrep -A1 "<key>CFBundleVersion</key>" | tr -dc '[0-9]\.')

	# $INFO does not contain any download URLs
URL='http://www.mothersruin.com/software/downloads/SuspiciousPackage.dmg'

RELEASE_NOTES_URL="https://www.mothersruin.com/software/SuspiciousPackage/relnotes.html"

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
	else
		echo "$NAME: Outdated: $INSTALLED_VERSION/$INSTALLED_BUILD vs $LATEST_VERSION/$LATEST_BUILD"
	fi

	FIRST_INSTALL='no'
else

	FIRST_INSTALL='yes'
fi

FILENAME="${DOWNLOAD_DIR_ALTERNATE-$HOME/Downloads}/${${INSTALL_TO:t:r}// /}-${${LATEST_VERSION}// /}_${${LATEST_BUILD}// /}.dmg"

RELEASE_NOTES_TXT="$FILENAME:r.txt"

if [[ -e "$RELEASE_NOTES_TXT" ]]
then

	cat "$RELEASE_NOTES_TXT"

else

	if (( $+commands[lynx] ))
	then

		RELEASE_NOTES=$(curl -sfLS "$RELEASE_NOTES_URL" \
						| awk '/<td class="vnotes">/{i++}i==1' \
						| sed '/<tr>/,$d' \
						| lynx 	-dump -width='10000' -display_charset=UTF-8 -assume_charset=UTF-8 \
								-pseudo_inlines -stdin  -nomargins -nonumbers)

		echo "${RELEASE_NOTES}\n\nSource: ${RELEASE_NOTES_URL}\nVersion: ${LATEST_VERSION} / ${LATEST_BUILD}\nURL: ${URL}" | tee "$RELEASE_NOTES_TXT"

	fi

fi

echo "$NAME: Downloading '$URL' to '$FILENAME':"

curl --continue-at - --fail --location --output "$FILENAME" "$URL"

EXIT="$?"

	## exit 22 means 'the file was already fully downloaded'
[ "$EXIT" != "0" -a "$EXIT" != "22" ] && echo "$NAME: Download of $URL failed (EXIT = $EXIT)" && exit 0

[[ ! -e "$FILENAME" ]] && echo "$NAME: $FILENAME does not exist." && exit 0

[[ ! -s "$FILENAME" ]] && echo "$NAME: $FILENAME is zero bytes." && rm -f "$FILENAME" && exit 0

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
	mv -f "$INSTALL_TO" "$HOME/.Trash/$INSTALL_TO:t:r.$INSTALLED_VERSION.app"
fi

echo "$NAME installing '$MNTPNT/$INSTALL_TO:t' to '$INSTALL_TO':"

ditto --noqtn "$MNTPNT/$INSTALL_TO:t" "$INSTALL_TO"

EXIT="$?"

if [ "$EXIT" = "0" ]
then

	INSTALLED_VERSION=$(defaults read "${INSTALL_TO}/Contents/Info" CFBundleShortVersionString)

	INSTALLED_BUILD=$(defaults read "${INSTALL_TO}/Contents/Info" CFBundleVersion)

	echo "$NAME: Successfully installed $INSTALL_TO:t ($INSTALLED_VERSION/$INSTALLED_BUILD)"

else
	echo "$NAME: 'ditto' failed (\$EXIT = $EXIT)"

	exit 1
fi

	# We need to launch the app at least once in order to use its QuickLook plugins
if [[ "$FIRST_INSTALL" == 'yes' ]]
then

	echo "$NAME: This is the first time we have installed $INSTALL_TO:t:r. Launching it in order to register its QuickLook plugins."

	open -a "$INSTALL_TO"

fi

if (( $+commands[unmount.sh] ))
then
	unmount.sh "$MNTPNT"
else
	diskutil eject "$MNTPNT"
fi

	# we'll try to install 'spkg' if we can

if ((! $+commands[spkg] ))
then

	SPKG="$INSTALL_TO/Contents/SharedSupport/spkg"

	if [[ -e "$SPKG" ]]
	then
		if [[ -w /usr/local/bin ]]
		then
			ln -s "$SPKG" /usr/local/bin/spkg && \
			echo "$NAME: Linked $SPKG to /usr/local/bin/spkg"
		else
			echo "$NAME: cannot link $SPKG to /usr/local/bin because it is not writable."
		fi
	else
		echo "$NAME: Did not find 'spkg' at $SPKG"
	fi
fi

exit 0
#
#EOF
