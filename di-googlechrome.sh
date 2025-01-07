#!/usr/bin/env zsh -f
# Purpose: Download and install/update the latest version Google Chrome
#
# From:	Timothy J. Luoma
# Mail:	luomat at gmail dot com
# Date:	2019-08-07

NAME="$0:t:r"

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
fi

	# must be in /Applications/ for 1Password
INSTALL_TO='/Applications/Google Chrome.app'

STAGING_DIR="$HOME/Downloads"

if [ -e "$STAGING_DIR" -a ! -w "$STAGING_DIR" ]
then
	echo "$NAME [FATAL] Staging dir '$STAGING_DIR' exists but is not writable." >>/dev/stderr
	exit 2
fi

	## @TODO - use 'https://chromiumdash.appspot.com' instead? Need to check into it and probably brew too

	## Thanks to brew cask for finding this URL. Might not be official, but better than nothing
LATEST_VERSION=$(curl -sfLS 'https://omahaproxy.appspot.com/history?os=mac;channel=stable' \
				| awk -F',' '/^mac/{print $3}' \
				| head -1 \
				| tr -dc '[0-9]\.')

if [[ "$LATEST_VERSION" == "" ]]
then
	echo "$NAME: Unable to determine latest version of Google Chrome."
	exit 1
fi


if [[ -e "$INSTALL_TO" ]]
then

	INSTALLED_VERSION=$(defaults read "${INSTALL_TO}/Contents/Info" CFBundleShortVersionString)

	if [[ "$INSTALLED_VERSION" == "$LATEST_VERSION" ]]
	then
		echo "$NAME: Up-to-date ($INSTALLED_VERSION)"
		exit 0
	fi

	autoload is-at-least

	is-at-least "$LATEST_VERSION" "$INSTALLED_VERSION"

	VERSION_COMPARE="$?"

	if [ "$VERSION_COMPARE" = "0" ]
	then
		echo "$NAME: Up-To-Date (Installed: '$INSTALLED_VERSION' vs Latest: '$LATEST_VERSION')"
		exit 0
	fi

	echo "$NAME: Outdated: $INSTALLED_VERSION vs $LATEST_VERSION"

	FIRST_INSTALL='no'

else

	FIRST_INSTALL='yes'
fi

	# 2021-01-19 - this is a universal (Intel/Apple Silicon) build
URL='https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg'

	# We will assume, for now, at the version number is correct
	# but then we'll verify it at the end
FILENAME="$HOME/Downloads/GoogleChrome-${LATEST_VERSION}.dmg"

	# There is no way, that I know of, to check the current version,
	# so I just download the current version
echo "$NAME: Downloading '$URL' to '$FILENAME':"

curl --continue-at - --progress-bar --fail --location --output "$FILENAME" "$URL"

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

	###############################################################################################
	###############################################################################################
	##
	## Just because the appcast version number was newer than my installed version
	## does not mean it is not also possible that Google's servers have an _even_newer_ version.
	##
	## Therefore, we check the version number from the DMG against the version number
	## from the appcast and see if they are the same.
	##
	## If they are not identical, then we rename the file to reflect its actual version number

DMG_VERSION=$(defaults read "$MNTPNT/$INSTALL_TO:t/Contents/Info" CFBundleShortVersionString)

if [[ "$DMG_VERSION" != "$LATEST_VERSION" ]]
then

	NEWNAME="$FILENAME:h/GoogleChrome-${DMG_VERSION}.dmg"

	if [[ -e "$NEWNAME" ]]
	then
		echo "\n\n$NAME: Would rename '$FILENAME' to '$NEWNAME' but '$NEWNAME' already exists."
	else
		echo "\n$NAME: Updating filename from '$FILENAME' to '$NEWNAME':\n"

		mv -vn "${FILENAME}" "${NEWNAME}"
	fi
fi



###############################################################################################
## Here is where we install from the DMG to the staging location

echo "$NAME: Staging '$MNTPNT/$INSTALL_TO:t' to '$INSTALL_TO'... "

ditto --noqtn -v "$MNTPNT/$INSTALL_TO:t" "$STAGING_DIR/$INSTALL_TO:t"

EXIT="$?"

if [[ "$EXIT" == "0" ]]
then
	echo "$NAME: ditto successfully staged"
else
	echo "$NAME: ditto failed" >>/dev/stderr
	exit 1
fi

###############################################################################################
## Here is where we move the old version (if it exists) to the trash

if [[ -e "$INSTALL_TO" ]]
then
		## NOTE: we will not automatically quit the app,
		## because there are too many things a browser could be doing
		## which would be very bad to interrupt by quitting suddenly

		# move installed version to trash
	mv -vf "$INSTALL_TO" "$HOME/.Trash/$INSTALL_TO:t:r.${INSTALLED_VERSION}.app"

	EXIT="$?"

	if [[ "$EXIT" != "0" ]]
	then

		echo "$NAME: failed to move '$INSTALL_TO' to Trash. ('mv' \$EXIT = $EXIT)"

		exit 1
	fi
fi


echo "$NAME: Final stage 'mv' of '$STAGING_DIR/$INSTALL_TO:t' to '$INSTALL_TO'...."

mv -nv "$STAGING_DIR/$INSTALL_TO:t" "$INSTALL_TO"

EXIT="$?"

if [[ "$EXIT" == "0" ]]
then
	echo "$NAME: SUCESS: 'mv' successfully exited."

else
 	echo "$NAME: 'mv' failed (\$EXIT = $EXIT)" >>/dev/stderr

 	exit 1
fi



[[ "$LAUNCH" = "yes" ]] && open -a "$INSTALL_TO"

echo -n "$NAME: Unmounting $MNTPNT: " && diskutil eject "$MNTPNT"

# if (( $+commands[delete-google-chrome-keystone-registration-framework.sh] ))
# then
#
# 		# This is my shell script that disbles Chrome's auto-update "feature"
# 	delete-google-chrome-keystone-registration-framework.sh
#
# fi
#
# 	# reveal file so it can be manually moved to /Applications/ folder
# open -R "$HOME/Downloads/Google Chrome.app"

exit 0
#EOF
