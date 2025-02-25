#!/usr/bin/env zsh -f
# Purpose: 	Download and install Flux
#
# From:		Timothy J. Luoma
# Mail:		luomat at gmail dot com
# Date:		2015-10-28
# Verified:	2025-02-24

NAME="$0:t:r"

INSTALL_TO='/Applications/Flux.app'

HOMEPAGE="https://justgetflux.com"

DOWNLOAD_PAGE="https://justgetflux.com/dlmac.html"

SUMMARY="f.lux makes the color of your computer's display adapt to the time of day, warm at night and like sunlight during the day."

XML_FEED='https://justgetflux.com/mac/macflux.xml'

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
fi

LAUNCH='no'

INFO=($(curl -sfL "$XML_FEED" \
		| tr -s ' ' '\012' \
		| egrep '^(url|sparkle:version)=' \
		| head -2 \
		| awk -F'"' '//{print $2}'))

URL="$INFO[1]"

LATEST_VERSION="$INFO[2]"

	# If any of these are blank, we should not continue
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

FILENAME="$HOME/Downloads/$INSTALL_TO:t:r-$LATEST_VERSION.zip"

if (( $+commands[lynx] ))
then

	(curl -sfLS "$XML_FEED" \
	| fgrep -v '<description>Most recent changes with links to updates.</description>' \
	| sed -e '1,/<description>/d; /<\/description>/,$d' -e 's#\]\]\>##g' -e 's#\<\!\[CDATA\[##g' \
	| awk '/<p>/{i++}i==1' \
	| lynx -dump -nomargins -width='10000' -assume_charset=UTF-8 -pseudo_inlines -stdin) \
	| tee "$FILENAME:r.txt"

fi

echo "$NAME: Downloading $URL to $FILENAME"

curl --continue-at - --fail --location --output "$FILENAME" "$URL"

EXIT="$?"

	## exit 22 means 'the file was already fully downloaded'
[ "$EXIT" != "0" -a "$EXIT" != "22" ] && echo "$NAME: Download of $URL failed (EXIT = $EXIT)" && exit 0

[[ ! -e "$FILENAME" ]] && echo "$NAME: $FILENAME does not exist." && exit 0

[[ ! -s "$FILENAME" ]] && echo "$NAME: $FILENAME is zero bytes." && rm -f "$FILENAME" && exit 0

pgrep Flux && LAUNCH='yes' && pkill Flux

echo "$NAME: Installing $FILENAME to $INSTALL_TO:h/"

ditto --noqtn -xk "$FILENAME" "$INSTALL_TO:h/"

EXIT="$?"

if [ "$EXIT" = "0" ]
then

	echo "$NAME: Successfully installed/updated $INSTALL_TO"

else
	echo "$NAME: ditto failed (\$EXIT = $EXIT)"

	exit 1
fi

[[ "$LAUNCH" = "yes" ]] && echo "$NAME: relaunching Flux" && open --background "$INSTALL_TO"

exit 0
#
#EOF
