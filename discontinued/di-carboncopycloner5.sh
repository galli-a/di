#!/bin/zsh -f
# Purpose: Download and install Carbon Copy Cloner, version 5
#
# From:	Timothy J. Luoma
# Mail:	luomat at gmail dot com
# Date:	2018-08-02

NAME="$0:t:r"
INSTALL_TO='/Applications/Carbon Copy Cloner.app'

	# if you want to install beta releases
	# create a file (empty, if you like) using this file name/path:
PREFERS_BETAS_FILE="$HOME/.config/di/carboncopycloner-prefer-betas.txt"

if [[ -e "$PREFERS_BETAS_FILE" ]]
then
	HEAD_OR_TAIL='tail'
	NAME="$NAME (beta releases)"
else
		## This is for official, non-beta versions
	HEAD_OR_TAIL='head'
fi

if [ -e "$HOME/.path" ]
then
	source "$HOME/.path"
else
	PATH='/usr/local/scripts:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin'
fi

	## NOTE: If nothing is installed, we need to pretend we have at least version 5
	## 			or else we will get version 3 or 4
INSTALLED_VERSION=`defaults read "$INSTALL_TO/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo '5.0.0'`

	## NOTE: If nothing is installed, we need to pretend we have at least version 5000
	## 			or else we will get version 3 or 4
INSTALLED_BUNDLE_VERSION=`defaults read "$INSTALL_TO/Contents/Info" CFBundleVersion 2>/dev/null || echo '5000'`

OS_MINOR=`sw_vers -productVersion | cut -d. -f 2`

OS_BUGFIX=`sw_vers -productVersion | cut -d. -f 3`

XML_FEED="https://bombich.com/software/updates/ccc.php?os_minor=$OS_MINOR&os_bugfix=$OS_BUGFIX&ccc=$INSTALLED_BUNDLE_VERSION&beta=0&locale=en"

# Replace 'head -3' with 'tail -3' if you want beta, instead of stable, releases
INFO=($(curl -sfL "$XML_FEED" \
		| egrep '"(version|build|downloadURL)":' \
		| ${HEAD_OR_TAIL} -3 \
		| tr -d ',|"' \
		| sort ))

# sort gives us: build vs downloadURL vs version with each field being followed by the corresponding value
LATEST_BUILD="$INFO[2]"
URL="$INFO[4]"
LATEST_VERSION="$INFO[6]"

# If any of these are blank, we should not continue
if [ "$INFO" = "" -o "$LATEST_VERSION" = "" -o "$URL" = "" -o "$LATEST_BUILD" = "" ]
then
	echo "$NAME: Error: bad data received from ${XML_FEED}

	INFO: $INFO

	URL: $URL
	LATEST_VERSION: $LATEST_VERSION
	LATEST_BUILD: $LATEST_BUILD
	"
	exit 0
fi

if [[ -e "$INSTALL_TO" ]]
then
	if [[ "$LATEST_VERSION" == "$INSTALLED_VERSION" ]]
	then
		echo "$NAME: Up-To-Date ($INSTALLED_VERSION)"
		exit 0
	fi

	autoload is-at-least

	is-at-least "$LATEST_VERSION" "$INSTALLED_VERSION"

	if [ "$?" = "0" ]
	then
		echo "$NAME: Up-To-Date (Installed = $INSTALLED_VERSION vs Latest = $LATEST_VERSION)"
		exit 0
	fi

	echo "$NAME: Outdated (Installed = $INSTALLED_VERSION vs Latest = $LATEST_VERSION)"
fi

if (( $+commands[lynx] ))
then

	RELEASE_NOTES_URL=$(curl -sfLS "$XML_FEED" | awk -F'"' '/releaseNotes/{print $4}' | ${HEAD_OR_TAIL} -1)

	curl -sfLS "$RELEASE_NOTES_URL" \
	| gunzip \
	| sed '1,/<details open id="primary">/d; /<details>/,$d' \
	| lynx -dump -nomargins -width='10000' -assume_charset=UTF-8 -pseudo_inlines -stdin

	echo "\nSource: <$RELEASE_NOTES_URL>"

fi

FILENAME="$HOME/Downloads/CarbonCopyCloner-${LATEST_VERSION}_${LATEST_BUILD}.zip"

echo "$NAME: Downloading '$URL' to '$FILENAME':"

curl --continue-at - --progress-bar --fail --location --output "$FILENAME" "$URL"

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
	&& osascript -e 'tell application "$INSTALL_TO:t:r" to quit'

	echo "$NAME: Moving existing (old) '$INSTALL_TO' to '$HOME/.Trash/'."

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
#EOF
