#!/bin/sh
# Stardew Valley ("compatibility" branch) on Mono + PortMaster's MonoGame + gl4es, from the player's own game in
# data/game (import.sh puts it there). The App Installer's app runs it in its folder. Log: HOME/logs/stardew.log.
# Overrides (LIBGL_*, MONO_*, SDV_*...) go in data/env, one VAR=value per line.
. ./common.sh
log=$HOME/logs/stardew.log
mkdir -p "$HOME/logs"

export MONOGAME_PATCH=$data/StardewPatches.dll
export SDL_VIDEO_GL_DRIVER=$app/gl4es/libGL.so.1
export SDL_VIDEO_EGL_DRIVER=$app/gl4es/libEGL.so.1
export LIBGL_ES=2 LIBGL_GL=21
[ -f "$data/env" ] && { set -a; . "$data/env"; set +a; }

# The game's language follows Puppy's whenever Puppy's changes; a choice made in the game sticks until then
language() {
    prefs=$HOME/.config/StardewValley/startup_preferences
    puppy=$(puppy_language)
    [ "$puppy" != "$(cat "$data/.language" 2>/dev/null)" ] || return 0
    case $puppy in pt*) lang=pt ;; es*) lang=es ;; *) lang=en ;; esac
    if [ -f "$prefs" ]; then
        sed -i "s|<languageCode>[^<]*</languageCode>|<languageCode>$lang</languageCode>|" "$prefs"
    else
        mkdir -p "${prefs%/*}"
        printf '<?xml version="1.0" encoding="utf-8"?>\n<StartupPreferences xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">\n  <languageCode>%s</languageCode>\n</StartupPreferences>\n' "$lang" > "$prefs"
    fi
    echo "$puppy" > "$data/.language"
}

{
    date
    if [ ! -f "$data/ready" ]; then
        echo "no game yet: Add your Stardew Valley (import.sh) puts it in $game"
        exit 1
    fi
    grep -E "MemTotal|MemAvailable|SwapFree|Shmem:" /proc/meminfo
    language
    # an update of the app brings the patches' sources, not the DLL: built here against the game, once
    patches_current || { echo "building StardewPatches.dll"; build_patches; } || { echo "StardewPatches.dll failed"; exit 1; }
    # the icon made from the game's title logo, over the app's own after an update
    [ ! -f "$data/icon.png" ] || cmp -s "$data/icon.png" "$app/icon.png" || cp "$data/icon.png" "$app/icon.png"
    cmp -s "$app/SdvLoader.exe" "$game/SdvLoader.exe" || cp "$app/SdvLoader.exe" "$game/"
    cd "$game" && mono SdvLoader.exe
    echo "exit $?"
} > "$log" 2>&1
