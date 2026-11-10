#!/usr/bin/env bash
# Stardew Valley on a console over its USB data port: put this checkout's port files on it, and time the title and a
# save load there with the bench mode (the game loads the save by itself, logs its times and exits). Each command
# first checks that the console holds the card named (HOME/.card-name), with the app and its game installed and no
# app open.
#   tools/console.sh saves <card>                      the save folders on the card
#   tools/console.sh send <card>                       the scripts, tools and patch sources of out/app (build.sh
#                                                      app) over MTP, over the installed app's: stardew.sh builds
#                                                      StardewPatches.dll again when it next starts the game
#   tools/console.sh bench <card> <name> <save> [VAR=value...]
#                                                      one run with SDV_BENCH=<save>,1,1 and the variables in
#                                                      data/env (the old env comes back after it), its log in
#                                                      out/results/console-<name>.log (~2 min)
# The daily card (extreme-daily) also needs --daily-card. The serial link is goodluckOS's dev/glserial.py
# (GOODLUCKOS: its checkout, ../goodluckOS by default).
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(dirname "$HERE")
OUT=$REPO/out
GLSERIAL=${GOODLUCKOS:-$(dirname "$REPO")/goodluckOS}/dev/glserial.py
H=/home/player
PORT=$H/apps/StardewValley
ENV=$PORT/data/env
LOG=$H/logs/stardew.log

usage() { sed -n 's/^#   //p' "$0"; exit 1; }
die() { echo "$*"; exit 1; }
g() { python3 "$GLSERIAL" cmd "$@" | tr -d '\r'; }

DAILY=
args=()
for a in "$@"; do if [ "$a" = --daily-card ]; then DAILY=1; else args+=("$a"); fi; done
set -- ${args[@]+"${args[@]}"}
[ $# -ge 2 ] || usage
act=$1 card=$2

check_console() {
    local out have
    [ "$card" != extreme-daily ] || [ -n "$DAILY" ] || die "extreme-daily is the daily card: add --daily-card to go ahead"
    out=$(g "echo card=\$(head -n 1 $H/.card-name 2>/dev/null)" "appctl status" "[ -f $PORT/data/ready ] && echo has-port")
    have=$(echo "$out" | sed -n 's/^card=//p')
    [ "$have" = "$card" ] || die "the console has the card '$have', not $card: nothing was done"
    case $out in *"application cgroup: populated"*) die "an app is open on the console: close it first" ;; esac
    case $out in *has-port*) ;; *) die "no Stardew Valley app with its game in $PORT on $card" ;; esac
}

send() {
    local tmp n a=$OUT/app/StardewValley
    command -v mtp-sendfile >/dev/null || die "no mtp-sendfile (libmtp)"
    [ -f "$a/app.puppy" ] || die "no out/app: ./build.sh app first"
    tmp=$(mktemp -d)
    (cd "$a" && ls app.puppy common.sh import.sh stardew.sh Sdv*.exe src/*.cs) > "$tmp/list"
    n=$(wc -l < "$tmp/list" | tr -d ' ')
    COPYFILE_DISABLE=1 tar --no-xattrs -cf "$tmp/sdv-send.tar" -C "$a" -T "$tmp/list"
    check_console
    echo "== $n files ($(($(wc -c < "$tmp/sdv-send.tar") / 1024)) KB) to HOME over MTP"
    if [ "$(uname)" = Darwin ]; then killall ptpcamerad 2>/dev/null || true; fi
    mtp-sendfile "$tmp/sdv-send.tar" sdv-send.tar > "$tmp/mtp.log" 2>&1 || { cat "$tmp/mtp.log"; die "MTP failed: nothing was installed"; }
    g "cd $PORT && tar --no-same-owner -xf $H/sdv-send.tar && echo unpacked \$(tar -tf $H/sdv-send.tar | wc -l) && rm $H/sdv-send.tar && sync" --timeout 120
    rm -rf "$tmp"
    echo "OK: $card has them"
}

bench() {
    local name=$1 save=$2 log out i
    log=$OUT/results/console-$name.log
    shift 2
    check_console
    mkdir -p "$OUT/results"
    # the env goes back even if this is stopped
    trap 'g "if [ -f $ENV.bench-saved ]; then mv -f $ENV.bench-saved $ENV; else rm -f $ENV; fi; sync; echo env:; cat $ENV 2>/dev/null"' EXIT
    g "[ -f $ENV.bench-saved ] || { [ -f $ENV ] && cp $ENV $ENV.bench-saved; } ; printf '%s\n' $* SDV_BENCH=$save,1,1 > $ENV; cat $ENV; appctl launch-application 'cd $PORT && sh stardew.sh'"
    echo "== $name: title, load of $save, 2 s at the farm, exit"
    for i in $(seq 1 40); do
        sleep 10
        out=$(g "grep -E '^(bench|exit)' $LOG | tail -n 3")
        case $out in *"exit "*) break ;; esac
    done
    python3 "$GLSERIAL" get $LOG "$log" > /dev/null
    grep -E '^(bench|Early|speed|xmldump|exit)|Exception' "$log" | sed 's/^/  /'
}

case $act in
    saves) g "ls $H/.config/StardewValley/Saves/" ;;
    send) send ;;
    bench) [ $# -ge 4 ] || usage; bench "${@:3}" ;;
    *) usage ;;
esac
