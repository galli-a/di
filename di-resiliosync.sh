#!/usr/bin/env zsh -f
# Purpose: Download and install latest BitTorrent Sync (aka Resilio Sync)
#
# From:	Tj Luo.ma
# Mail:	luomat at gmail dot com
# Web: 	http://RhymesWithDiploma.com
# Date:	2014-10-11

	# 2018-08-02 - this is what the newest version available calls itself
#INSTALL_TO='/Applications/BitTorrent Sync.app'

INSTALL_TO='/Applications/Resilio Sync.app'

HOMEPAGE="https://www.resilio.com"

DOWNLOAD_PAGE="https://download-cdn.resilio.com/stable/osx/Resilio-Sync.dmg"

SUMMARY="Sync any folder to all your devices. Sync photos, videos, music, PDFs, docs or any other file types to/from your mobile phone, laptop, or NAS."

if [[ -e "$HOME/.path" ]]
then
	source "$HOME/.path"
fi

NAME="$0:t:r"

zmodload zsh/datetime

LOG="$HOME/Library/Logs/${NAME}.log"

[[ -d "$LOG:h" ]] || mkdir -p "$LOG:h"
[[ -e "$LOG" ]]   || touch "$LOG"

function timestamp { strftime "%Y-%m-%d at %H:%M:%S" "$EPOCHSECONDS" }

function log { echo "$NAME [`timestamp`]: $@" | tee -a "$LOG" }

TEMPFILE="${TMPDIR-/tmp}/${NAME}.${TIME}.$$.$RANDOM"

	# 2020-05-09 new update!
XML_FEED='https://update.resilio.com/cfu.php?forced=1&b=sync&lang=en&pl=mac&rn=81&sysver=10.15.4&v=33957721'

	# both Sparkle versions are identical
INFO=($(curl -sfLS \
	-H "Accept: application/rss+xml,*/*;q=0.1" \
	-H "Accept-Language: en-us" \
	-H "User-Agent: Resilio Sync/2.6.10073 Sparkle/1.16.0" \
	"${XML_FEED}" \
	| egrep -i 'releasenoteslink>|url=|sparkle:version=' \
	| sort \
	| tr -d '\r' \
	| sed -e 's#.*="##g' -e 's#"$##g' -e 's#.*<sparkle:releaseNotesLink>##g' -e 's#</sparkle:releaseNotesLink>##g' -e 's#amp\;##g'))

LATEST_VERSION="$INFO[1]"

URL="$INFO[2]"

RELEASE_NOTES_URL="$INFO[3]"

	# If any of these are blank, we should not continue
if [ "$LATEST_VERSION" = "" -o "$URL" = "" ]
then
	echo "$NAME: Error: bad data received:
	LATEST_VERSION: $LATEST_VERSION
	URL: $URL
	"

	exit 1
fi

####|####|####|####|####|####|####|####|####|####|####|####|####|####|####
#
#		Compare installed version with latest version
#

if [ -e "$INSTALL_TO" ]
then
	INSTALLED_VERSION=`defaults read $INSTALL_TO/Contents/Info CFBundleShortVersionString 2>/dev/null || echo 0`
	INSTALLED_BUILD=`$INSTALL_TO/Contents/MacOS/Resilio\ Sync --help | grep -e '(' | head -n 1 | cut -d "(" -f2 | cut -d ")" -f1`
else
	INSTALLED_VERSION='0'
fi
INSTALLED_VERSION=${INSTALLED_VERSION}'.'${INSTALLED_BUILD}

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

####|####|####|####|####|####|####|####|####|####|####|####|####|####|####
#
#		Download the latest version to a file with the version number in the name
#

FILENAME="$HOME/Downloads/${${INSTALL_TO:t:r}// /}-${LATEST_VERSION}.dmg"

if [[ -e "$FILENAME:r.txt" ]]
then

	cat "$FILENAME:r.txt"

else

	if (( $+commands[lynx] ))
	then

		RELEASE_NOTES=$(lynx -assume_charset=UTF-8 -pseudo_inlines -nolist -dump -nomargins -nonumbers -width=10000 "$RELEASE_NOTES_URL")

		echo "${RELEASE_NOTES}\n\nSource: ${RELEASE_NOTES_URL}\nVersion : ${LATEST_VERSION}\nURL: $URL" | tee "$FILENAME:r.txt"

	fi
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

[[ "$LAUNCH" = "yes" ]] && open -a "$INSTALL_TO:t:r"

echo -n "$NAME: Unmounting $MNTPNT: " && diskutil eject "$MNTPNT"

open -a "$INSTALL_TO:t:r"

exit 0
#
#EOF
