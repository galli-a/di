#!/usr/bin/env zsh -f
# Purpose: version 4
#
# From:	Timothy J. Luoma
# Mail:	luomat at gmail dot com
# Date:	2021-09-20

autoload is-at-least

NAME="$0:t:r"

[[ -e "$HOME/.path" ]] && source "$HOME/.path"

[[ -e "$HOME/.config/di/defaults.sh" ]] && source "$HOME/.config/di/defaults.sh"

INSTALL_TO="${INSTALL_DIR_ALTERNATE-/Applications}/Bartender 4.app"

XML_FEED='https://www.macbartender.com/B2/updates/updatesB4.php'

	# replace newlines, spaces, tabs, with one space
	# replace everything up to <item>
	# replace everything after </item>
	# replace the space in "> <" with a new line
	# replace all spaces with newlines
	# replace sparkle into with 'this'="foo" instead of <this>foo</this>
	# sort lines to get consistent output order
	# egrep to get just the lines we want
	# use awk to get just the values and not the fields

INFO=($(curl -sfLS "$XML_FEED" \
	| tr -s '\012| |\t' ' ' \
	| sed 	-e 's#.*<item>##g' \
		-e 's#</item>.*##g' \
		-e 's#> <#>\
<#g' -e 's# #\
#g' -e 's#<sparkle:minimumSystemVersion>#sparkle:minimumSystemVersion="#g' \
		-e 's#</sparkle:minimumSystemVersion>#"#g' \
		-e 's#<sparkle:releaseNotesLink>#sparkle:releaseNotesLink="#g' \
		-e 's#</sparkle:releaseNotesLink>#"#g' \
	| sort \
	| egrep 'sparkle:version|sparkle:shortVersionString|sparkle:releaseNotesLink|sparkle:minimumSystemVersion|url' \
	| awk -F'"' '{print $2}' ))

MIN_VERSION="$INFO[1]"
RELEASE_NOTES_URL="$INFO[2]"
LATEST_VERSION="$INFO[3]"
LATEST_BUILD="$INFO[4]"
URL="$INFO[5]"

	# If any of these are blank, we cannot continue
if [ "$INFO" = "" -o "$URL" = "" -o "$LATEST_VERSION" = "" -o "$LATEST_BUILD" = "" ]
then
	echo "$NAME: Error: bad data received:
	INFO: $INFO
	LATEST_VERSION: $LATEST_VERSION
	LATEST_BUILD: $LATEST_BUILD
	URL: $URL
	"  >>/dev/stderr

	exit 1
fi

ACTUAL_VERSION=$(sw_vers -productVersion)

is-at-least "$MIN_VERSION" "$ACTUAL_VERSION"

EXIT="$?"

if [[ "$EXIT" == "1" ]]
then
	echo "$NAME: '$INSTALL_TO:t' requires '$MIN_VERSION' to install but you are running '$ACTUAL_VERSION'." >>/dev/stderr

	exit 2
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

	if [[ ! -w "$INSTALL_TO" ]]
	then
		echo "$NAME: '$INSTALL_TO' exists, but you do not have 'write' access to it, therefore you cannot update it." >>/dev/stderr

		exit 2
	fi

else

	FIRST_INSTALL='yes'
fi

FILENAME="${DOWNLOAD_DIR_ALTERNATE-$HOME/Downloads}/Bartender-${${LATEST_VERSION}// /}_${${LATEST_BUILD}// /}.zip"

RELEASE_NOTES_TXT="$FILENAME:r.txt"

if [[ -e "$RELEASE_NOTES_TXT" ]]
then

	cat "$RELEASE_NOTES_TXT"

else

	if (( $+commands[html2text.py] ))
	then
			# html2text.py will give us something like markdown
			# uniq will make sure we don't have more than one blank line in a row
		RELEASE_NOTES=$(curl -sfLS "$RELEASE_NOTES_URL" | html2text.py | uniq)

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

egrep -q '^Local sha256:$' "$FILENAME:r.txt" 2>/dev/null

EXIT="$?"

if [ "$EXIT" = "1" -o ! -e "$FILENAME:r.txt" ]
then
	(cd "$FILENAME:h" ; \
	echo "\n\nLocal sha256:" ; \
	shasum -a 256 "$FILENAME:t" \
	)  >>| "$FILENAME:r.txt"
fi


TEMPDIR=$(mktemp -d "${TMPDIR-/tmp/}${NAME-$0:r}-XXXXXXXX")

	## make sure that the .zip is valid before we proceed
(command unzip -l "$FILENAME" 2>&1 )>/dev/null

EXIT="$?"

if [ "$EXIT" = "0" ]
then
	echo "$NAME: '$FILENAME' is a valid zip file."

else
	echo "$NAME: '$FILENAME' is an invalid zip file (\$EXIT = $EXIT)"

	mv -fv "$FILENAME" "$TEMPDIR/"

	mv -fv "$FILENAME:r".* "$TEMPDIR/"

	exit 0

fi

	## unzip to a temporary directory
UNZIP_TO=$(mktemp -d "${TEMPDIR}/${NAME}-XXXXXXXX")

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
	&& osascript -e "tell application \"$INSTALL_TO:t:r\" to quit"

	echo "$NAME: Moving existing (old) '$INSTALL_TO' to '$TEMPDIR/'."

	mv -f "$INSTALL_TO" "$TEMPDIR/$INSTALL_TO:t:r.$INSTALLED_VERSION.app"

	EXIT="$?"

	if [[ "$EXIT" != "0" ]]
	then

		echo "$NAME: failed to move existing '$INSTALL_TO' to '$TEMPDIR'."

		exit 1
	fi
fi

echo "$NAME: Moving new version of '$INSTALL_TO:t' (from '$UNZIP_TO') to '$INSTALL_TO'."

	# Move the file out of the folder
mv -n "$UNZIP_TO/$INSTALL_TO:t" "$INSTALL_TO"

EXIT="$?"

if [[ "$EXIT" = "0" ]]
then

	echo "$NAME: Successfully installed '$UNZIP_TO/$INSTALL_TO:t' to '$INSTALL_TO'."

else
	echo "$NAME: Failed to move '$UNZIP_TO/$INSTALL_TO:t' to '$INSTALL_TO'."

	exit 1
fi

[[ "$LAUNCH" = "yes" ]] && open "$INSTALL_TO"

exit 0
#EOF
