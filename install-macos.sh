#!/bin/sh
set -eu

game_pattern='minecraft.*net.fabricmc.loader.impl.launch.knot.KnotClient'
if pgrep -f "$game_pattern" >/dev/null 2>&1; then
	echo "Close Minecraft before installation." >&2
	exit 1
fi

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
minecraft_dir="${1:-$HOME/Library/Application Support/minecraft}"
mods_dir="$minecraft_dir/mods"
version=$(sed -n 's/^version=//p' "$project_dir/gradle.properties")
source_jar="$project_dir/build/libs/minecraft-speech-to-text-$version.jar"
destination="$mods_dir/minecraft-speech-to-text-$version.jar"
helper_root="$minecraft_dir/minecraft-speech-to-text"
helper_destination="$helper_root/Minecraft Speech to Text Helper.app"
helper_source="$project_dir/native/macos/SpeechToTextHelper.swift"
helper_plist="$project_dir/native/macos/Info.plist"

if [ ! -f "$source_jar" ]; then
	echo "Build the mod first with ./gradlew build." >&2
	exit 1
fi

mkdir -p "$mods_dir" "$helper_root"
temporary=$(mktemp "$mods_dir/.minecraft-speech-to-text-install.XXXXXX.jar")
helper_temporary=$(mktemp -d "$helper_root/.speech-helper.XXXXXX")
trap 'rm -f "$temporary"; rm -rf -- "$helper_temporary"' EXIT HUP INT TERM
cp "$source_jar" "$temporary"
unzip -tq "$temporary" >/dev/null

mkdir -p "$helper_temporary/Contents/MacOS"
cp "$helper_plist" "$helper_temporary/Contents/Info.plist"
xcrun swiftc -swift-version 5 "$helper_source" \
	-o "$helper_temporary/Contents/MacOS/SpeechToTextHelper" \
	-framework AppKit -framework AVFoundation -framework Speech
chmod 755 "$helper_temporary/Contents/MacOS/SpeechToTextHelper"
codesign --force --deep --sign - "$helper_temporary" >/dev/null

if [ -d "$helper_destination" ]; then
	helper_backup=$(mktemp -d "$helper_root/.speech-helper-backup.XXXXXX")
	rmdir "$helper_backup"
	mv "$helper_destination" "$helper_backup"
fi
mv "$helper_temporary" "$helper_destination"
for old_mod in "$mods_dir"/minecraft-speech-to-text-*.jar; do
	[ "$old_mod" = "$destination" ] || [ ! -f "$old_mod" ] || rm -f -- "$old_mod"
done
mv -f "$temporary" "$destination"
trap - EXIT HUP INT TERM

echo "Installed $destination"
echo "Installed $helper_destination"
if find "$mods_dir" -maxdepth 1 -name 'magic-craft-*.jar' -print -quit | grep -q .; then
	echo "Warning: Magic Craft is also installed and uses V. Disable one V key in Minecraft Controls."
fi

