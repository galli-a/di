#!/bin/zsh -f
# Purpose: Download and install latest version of DetectX Swift
#
# From:	Timothy J. Luoma
# Mail:	luomat at gmail dot com
# Date:	2015-12-15

NAME="$0:t:r"

INSTALL_TO='/Applications/DetectX Swift.app'

HOMEPAGE="https://sqwarq.com/detectx/"

DOWNLOAD_PAGE="https://sqwarq.com/detectx/"

SUMMARY="DetectX Swift is a lightweight, on-demand dedicated search and troubleshooting tool that can identify malware, adware, keyloggers, potentially unwanted apps and potentially destabilising apps on a Mac."

RELEASE_NOTES_URL='https://s3.amazonaws.com/sqwarq.com/AppCasts/dtxswift_release_notes.html'

if [ -e "$HOME/.path" ]
then
	source "$HOME/.path"
else
	PATH='/usr/local/scripts:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin'
fi

XML_FEED='https://s3.amazonaws.com/sqwarq.com/AppCasts/dtxswift.xml'

	# no other version info in feed
INFO=($(curl -sfL "$XML_FEED" \
		| tr -s ' ' '\012' \
		| egrep 'sparkle:version=|url=' \
		| head -2 \
		| sort \
		| awk -F'"' '/^/{print $2}'))

	# "Sparkle" will always come before "url" because of "sort"
LATEST_VERSION="$INFO[1]"

URL="$INFO[2]"

if [ "$INFO" = "" -o "$LATEST_VERSION" = "" -o "$URL" = "" ]
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

	INSTALLED_VERSION=`defaults read "$INSTALL_TO/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo '0'`

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

if (( $+commands[lynx] ))
then

	( echo "$NAME: Release Notes for $INSTALL_TO:t:r:" ;
	curl -sfLS "$RELEASE_NOTES_URL" \
	| awk '/<p id="version">/{i++}i==1' \
	| lynx -dump -nomargins -width='10000' -assume_charset=UTF-8 -pseudo_inlines -stdin ;
	echo "\nSource: <$RELEASE_NOTES_URL>") \
	| tee -a "$FILENAME:r.txt"

fi

FILENAME="$HOME/Downloads/DetectXSwift-${LATEST_VERSION}.zip"

echo "$NAME: Downloading $URL to $FILENAME"

curl --continue-at - --progress-bar --fail --location --output "$FILENAME" "$URL"

EXIT="$?"

	## exit 22 means 'the file was already fully downloaded'
[ "$EXIT" != "0" -a "$EXIT" != "22" ] && echo "$NAME: Download of $URL failed (EXIT = $EXIT)" && exit 0

echo "$NAME: Installing $FILENAME to $INSTALL_TO:h/"

	# Extract from the .zip file and install (this will leave the .zip file in place)
ditto --noqtn -xk "$FILENAME" "$INSTALL_TO:h/"

EXIT="$?"

if [ "$EXIT" = "0" ]
then
	echo "$NAME: Installation of $INSTALL_TO was successful."

	[[ "$LAUNCH" == "yes" ]] && open -a "$INSTALL_TO"

else
	echo "$NAME: Installation of $INSTALL_TO failed (ditto \$EXIT = $EXIT)\nThe downloaded file can be found at $FILENAME."

	exit 1
fi

exit 0
#EOF