#!/usr/bin/env bash
# The app's import on the PC: the newest out/StardewValley-*.zip unpacked into a HOME of its own (out/test-home), the
# game of SDV_GAME put there as a folder (or as a zip of one, with "zip"), and app/import.sh run by BusyBox's sh and
# applets with the port's own Mono under qemu-arm, as on the console (only much slower), in an image with only what
# goodluckOS has (apptest.Dockerfile).
#   tools/apptest.sh [folder|zip]          TEST_LANGUAGE=en for the English messages (default pt-BR)
#   tools/apptest.sh zip <file.zip>        that zip of a game instead (a path in this checkout, as out/x.zip)
#   tools/apptest.sh resume                import.sh again on the HOME as it is
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(dirname "$HERE")
SDV_GAME=${SDV_GAME:-$HOME/Library/Application Support/Steam/steamapps/common/Stardew Valley}
if [ ! -f /.dockerenv ]; then
    [ -d "$SDV_GAME" ] || { echo "no game in SDV_GAME"; exit 1; }
    docker image inspect glosports-stardew-apptest >/dev/null 2>&1 ||
        docker build -t glosports-stardew-apptest -f "$HERE/apptest.Dockerfile" "$HERE"
    exec docker run --rm -i -e TEST_LANGUAGE="${TEST_LANGUAGE:-pt-BR}" -v "$REPO:/repo" -v "$SDV_GAME:/game:ro" \
        glosports-stardew-apptest /repo/tools/apptest.sh "$@"
fi

H=/repo/out/test-home
a=$H/apps/StardewValley
zip=$(ls -t /repo/out/StardewValley-*.zip | head -n 1)
mkdir -p /tmp/bb && busybox --install -s /tmp/bb
if [ "${1:-}" != resume ]; then
rm -rf "$H"
mkdir -p "$H/apps" "$H/.config/puppy"
echo "language=$TEST_LANGUAGE" > "$H/.config/puppy/settings"
python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$zip" "$H/apps"
# Mono finds its lib/ and etc/ from its own path, only when it is named mono in a bin/: the real one goes to mono/q/bin,
# run under qemu-arm by wrappers where the app looks for it; Mono's CodeDom finds q/bin/mcs, which runs the app's own
# mcs. The wrappers are dash, not the setuid sh, so they keep LD_LIBRARY_PATH as the console's direct exec would
mkdir -p "$a/mono/q/bin"
mv "$a/mono/bin/mono" "$a/mono/q/bin/mono"
ln -s ../lib "$a/mono/q/lib"
ln -s ../etc "$a/mono/q/etc"
printf '#!/bin/dash\nexec qemu-arm "$(dirname "$0")/../q/bin/mono" "$@"\n' > "$a/mono/bin/mono"
printf '#!/bin/dash\nexec "$(dirname "$0")/../../bin/mcs" "$@"\n' > "$a/mono/q/bin/mcs"
chmod +x "$a/mono/bin/mono" "$a/mono/bin/mcs" "$a/mono/q/bin/mono" "$a/mono/q/bin/mcs"
if [ "${1:-folder}" = zip ] && [ -n "${2:-}" ]; then
    cp "/repo/$2" "$H/"
elif [ "${1:-folder}" = zip ]; then
    python3 -c 'import os, sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk("/game"):
        for f in files:
            p = os.path.join(root, f)
            z.write(p, os.path.join("Stardew Valley", os.path.relpath(p, "/game")))' "$H/Stardew Valley.zip"
else
    cp -r /game "$H/Stardew Valley"
fi
echo "== ${zip##*/}, the game as a ${1:-folder} in $H"
fi

start=$(date +%s)
chown -R player "$H"
setpriv --reuid=player --regid=player --clear-groups env HOME=$H PATH=/tmp/bb:$PATH sh -c "cd '$a' && sh import.sh" ||
    echo "import.sh exit $?"
echo "== $(( $(date +%s) - start )) s"
cat "$H/logs/stardew-import.log"
ls -la "$a/data" && ls "$a/data/game" | head -40 && cat "$a/data/ready" 2>/dev/null
