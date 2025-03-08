#!/usr/bin/env zsh -f
# Purpose: 	Download and install Audio Hijack 4
#
# From:		Tj Luo.ma
# Mail:		luomat at gmail dot com
# Web: 		http://RhymesWithDiploma.com
# Date:		2015-01-20
# Verified:	2025-02-21

[[ -e "$HOME/.path" ]] && source "$HOME/.path"

[[ -e "$HOME/.config/di/defaults.sh" ]] && source "$HOME/.config/di/defaults.sh"

INSTALL_TO="${INSTALL_DIR_ALTERNATE-/Applications}/Audio Hijack.app"


NAME="$0:t:r"

HOMEPAGE="https://www.rogueamoeba.com/audiohijack/"

DOWNLOAD_PAGE="https://rogueamoeba.com/audiohijack/download.php"

SUMMARY="Record any application’s audio, including VoIP calls from Skype, web streams from Safari, and much more. Save audio from hardware devices like microphones and mixers as well. You can even record all the audio heard on your Mac at once! If you can hear it, Audio Hijack can record it."

zmodload zsh/datetime

function timestamp { strftime "%Y-%m-%d at %H:%M:%S" "$EPOCHSECONDS" }

RELEASE_NOTES_URL='https://www.rogueamoeba.com/support/releasenotes/?product=Audio+Hijack'

	# Web page scraping is the lowest form of life, but it's all we have
LATEST_VERSION=$(curl -sfLS "$RELEASE_NOTES_URL" \
	| fgrep 'ra-product="audio-hijack"' \
	| head -1 \
	| sed "s#.*<div id='##g; s#' .*##g")

	## I used to calculate this from the $DOWNLOAD_PAGE but now I don't
URL='https://rogueamoeba.com/audiohijack/download/AudioHijack.zip'

if [[ "$URL" == "" ]]
then
	echo "$NAME: URL is empty"
	exit 1
fi

	# If any of these are blank, we should not continue
if [ "$LATEST_VERSION" = "" ]
then
	echo "$NAME: Error: bad data received:
	LATEST_VERSION: $LATEST_VERSION
	"

	exit 1
fi

if [ -d "$INSTALL_TO" ]
then
	INSTALLED_VERSION=`defaults read "$INSTALL_TO/Contents/Info" CFBundleVersion 2>/dev/null || echo 0`

	if [[ "$LATEST_VERSION" == "$INSTALLED_VERSION" ]]
	then
		echo "$NAME: Up-To-Date ($INSTALLED_VERSION)"
		exit 0
	fi

	autoload is-at-least

	is-at-least "$LATEST_VERSION" "$INSTALLED_VERSION"

	if [ "$?" = "0" ]
	then
		echo "$NAME: Installed version ($INSTALLED_VERSION) is ahead of official version $LATEST_VERSION"
		exit 0
	fi

	echo "$NAME: Outdated (Installed = $INSTALLED_VERSION vs Latest = $LATEST_VERSION)"
fi

FILENAME="${DOWNLOAD_DIR_ALTERNATE-$HOME/Downloads}/${${INSTALL_TO:t:r}// /}-${${LATEST_VERSION}// /}.zip"

if (( $+commands[lynx] ))
then

	RELEASE_NOTES=$(curl -sfLS "$RELEASE_NOTES_URL" \
					| sed   -e '1,/ra-product="audio-hijack"/d' \
							-e '/<!-- end .version-note -->/,$d' \
					| lynx -dump -nomargins -width=10000 -assume_charset=UTF-8 -pseudo_inlines -stdin)

	echo "${RELEASE_NOTES}\nSource: ${RELEASE_NOTES_URL}\nURL: ${URL}" | tee "$FILENAME:r.txt"

fi

echo "$NAME: Downloading '$URL' to '$FILENAME':"

curl --continue-at - --fail --location --output "$FILENAME" "$URL"

EXIT="$?"

	## exit 22 means 'the file was already fully downloaded'
[ "$EXIT" != "0" -a "$EXIT" != "22" ] && echo "$NAME: Download of $URL failed (EXIT = $EXIT)" && exit 0

[[ ! -e "$FILENAME" ]] && echo "$NAME: $FILENAME does not exist." && exit 0

[[ ! -s "$FILENAME" ]] && echo "$NAME: $FILENAME is zero bytes." && rm -f "$FILENAME" && exit 0

(cd "$FILENAME:h" ; echo "\nLocal sha256:" ; shasum -a 256 "$FILENAME:t" ) >>| "$FILENAME:r.txt"

	## make sure that the .zip is valid before we proceed
(command unzip -l "$FILENAME" 2>&1 )>/dev/null

EXIT="$?"

if [ "$EXIT" = "0" ]
then
	echo "$NAME: '$FILENAME' is a valid zip file."

else
	echo "$NAME: '$FILENAME' is an invalid zip file (\$EXIT = $EXIT)"

	mv -fv "$FILENAME" "$HOME/.Trash/"

	mv -fv "$FILENAME:r".* "$HOME/.Trash/"

	exit 0

fi

	## unzip to a temporary directory
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
	&& echo "$NAME: '$INSTALL_TO:t' is running. Not replacing it." \
	&& exit 1

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
#
#EOF
