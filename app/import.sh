#!/bin/sh
# import.sh, "Add your Stardew Valley": takes the player's own copy of the game from HOME (a folder or a zip with
# StardewValley.exe in it: Steam's compatibility branch, macOS or Linux), moves what the port needs into data/game
# and makes the rest from it: StardewPatches.dll, the launcher icon, LZ4 .xnb files and the save serializers.
# The app's second launcher entry runs it, as the player, on the text console, in the app's folder. Nothing of the
# copy is lost when a step fails: data/import keeps it, and the next run goes on from there.
. ./common.sh
LOG=$HOME/logs/stardew-import.log
work=$data/import
TESTED=1.6.15
mkdir -p "$HOME/logs"

# the Portuguese is here, not in goodluckOS's pt-BR.lang, so that the app brings its messages' translation
LANGUAGE=$(puppy_language)
translate() {
    [ "$LANGUAGE" = pt-BR ] || return 0
    awk -v key="$1" 'index($0, key " = ") == 1 { print substr($0, length(key) + 4); exit }' <<'LANG'
Looking for your Stardew Valley in HOME... = Procurando o seu Stardew Valley na HOME...
Found in %s = Encontrado em %s
Going on with the copy from last time = Continuando com a cópia da última vez
No Stardew Valley in HOME. Copy your game's folder, or a zip of it, to HOME: Steam's compatibility branch, the macOS or Linux version (the one with StardewValley.exe) = Nenhum Stardew Valley na HOME. Copie a pasta do seu jogo, ou um zip dela, para a HOME: o ramo compatibility da Steam, na versão de macOS ou Linux (a que tem StardewValley.exe)
This is the Windows version, which the port can't run yet: copy the macOS or Linux version = Esta é a versão de Windows, que o port ainda não roda: copie a versão de macOS ou Linux
Version %s of the game; the port is tested with %s = Versão %s do jogo; o port foi testado com a %s
Not enough room in HOME: %s MB free, %s MB needed = Falta espaço na HOME: %s MB livres, %s MB necessários
Unpacking the zip... = Descompactando o zip...
The zip could not be unpacked: is it whole? = Não deu para descompactar o zip: ele está inteiro?
Moving the game into the app... = Movendo o jogo para dentro do app...
Could not move the game: is HOME full? = Não deu para mover o jogo: a HOME está cheia?
Building the port's patches against your game... = Compilando as correções do port para o seu jogo...
The patches don't build against this version of the game: see HOME/logs/stardew-import.log = As correções não compilam com esta versão do jogo: veja HOME/logs/stardew-import.log
Making the icon from the title logo... = Fazendo o ícone a partir do logo da tela título...
Repacking the game's images for a faster start (several minutes)... = Recompactando as imagens do jogo para abrir mais rápido (vários minutos)...
Repacking failed: see HOME/logs/stardew-import.log = A recompactação falhou: veja HOME/logs/stardew-import.log
Making the save serializers (several minutes)... = Gerando os leitores de save (vários minutos)...
The save serializers failed: see HOME/logs/stardew-import.log = Os leitores de save falharam: veja HOME/logs/stardew-import.log
Stardew Valley is ready: open it in the Games tab = O Stardew Valley está pronto: abra na aba Jogos
The zip was removed: the game is in the app now = O zip foi apagado: o jogo agora está dentro do app
What is left in %s isn't needed any more and can be deleted = O que sobrou em %s não é mais necessário e pode ser apagado
Run Add your Stardew Valley again to go on from here = Rode Add your Stardew Valley de novo para continuar daqui
Back to the menu in %s s = Voltando ao menu em %s s
LANG
}

# the console's font has no accents; one letter at a time, as BusyBox's sed reads a [...] of them byte by byte
ascii() {
    printf '%s' "$1" | sed 's/á/a/g; s/à/a/g; s/â/a/g; s/ã/a/g; s/é/e/g; s/ê/e/g; s/í/i/g; s/ó/o/g; s/ô/o/g; s/õ/o/g;
        s/ú/u/g; s/ç/c/g; s/Á/A/g; s/À/A/g; s/Â/A/g; s/Ã/A/g; s/É/E/g; s/Ê/E/g; s/Í/I/g; s/Ó/O/g; s/Ô/O/g; s/Õ/O/g;
        s/Ú/U/g; s/Ç/C/g'
}

# say "English text with %s" [args]: translated as Puppy is, on the screen and in the log
say() {
    _fmt=$(translate "$1")
    [ -n "$_fmt" ] || _fmt=$1
    shift
    _msg=$(printf "$_fmt" "$@")
    ascii "$_msg" | fold -s -w 76 | sed 's/^/  /'
    printf '\n'
    echo "$(date '+%F %T') $_msg" >> "$LOG"
}

finish() {
    sync
    printf '\n'
    say "Back to the menu in %s s" 10
    sleep 10
    exit "$1"
}

fail() {
    say "$@"
    [ -d "$work" ] && say "Run Add your Stardew Valley again to go on from here"
    finish 1
}

# a step's output goes to the log only
run() {
    echo "$(date '+%F %T') \$ $*" >> "$LOG"
    "$@" >> "$LOG" 2>&1
}

free_mb() {
    df -k "$HOME" | tail -n 1 | awk '{ print int($(NF - 2) / 1024) }'
}

# what the game folder holds that the port brings its own of (Mono's class libraries, MonoGame, native libraries)
ours() {
    case ${1##*/} in
        System.Data.HashFunction.*) return 1 ;;
        MonoGame.Framework.*|mscorlib.dll|Mono.*|System*|WindowsBase.dll|lib*) return 0 ;;
    esac
    return 1
}

# into $work from the folder $1 that holds StardewValley.exe: Content first and the exe last, so that a copy cut
# short is either still found in HOME by its exe or complete in $work
take() {
    _bin=$1
    _content=$_bin/Content
    [ -d "$_content" ] || _content=${_bin%/*}/Resources/Content
    mkdir -p "$work" || return 1
    if [ ! -d "$work/Content" ]; then
        mv "$_content" "$work/Content" || return 1
    fi
    for _f in "$_bin"/*.dll "$_bin"/*.dll.config "$_bin"/*.exe; do
        [ -f "$_f" ] && [ "${_f##*/}" != StardewValley.exe ] || continue
        ours "$_f" || mv -f "$_f" "$work/" || return 1
    done
    mv -f "$_bin/StardewValley.exe" "$work/" && : > "$work/.copied"
}

# the first string that starts like 1.6.15 (it is 1.6.15.24356 in the exe)
version() {
    strings "$1" | sed -n 's/^\(1\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | sed -n 1p
}

echo "$(date '+%F %T') import, app $(sed -n 's/^VERSION=//p' app.puppy | head -n 1)" >> "$LOG"
printf '\n  Stardew Valley\n\n'
zip=
if [ -f "$work/.copied" ]; then
    say "Going on with the copy from last time"
else
    say "Looking for your Stardew Valley in HOME..."
    exe=$(find "$HOME" -maxdepth 6 \( -path "$HOME/.*" -o -path "$HOME/apps" \) -prune -o -type f -name StardewValley.exe -print |
        sed -n 1p)
    if [ -z "$exe" ]; then
        for z in "$HOME"/*.zip "$HOME"/apps/*.zip; do
            [ -f "$z" ] && unzip -l "$z" 2>/dev/null | grep -q 'StardewValley\.exe$' && zip=$z && break
        done
    fi
    if [ -z "$exe" ] && [ -z "$zip" ]; then
        if find "$HOME" -maxdepth 6 \( -path "$HOME/.*" -o -path "$HOME/apps" \) -prune -o -type f -name 'Stardew Valley.exe' -print |
                grep -q .; then
            fail "This is the Windows version, which the port can't run yet: copy the macOS or Linux version"
        fi
        fail "No Stardew Valley in HOME. Copy your game's folder, or a zip of it, to HOME: Steam's compatibility branch, the macOS or Linux version (the one with StardewValley.exe)"
    fi
    if [ -n "$exe" ]; then
        say "Found in %s" "${exe#$HOME/}"
    else
        say "Found in %s" "${zip#$HOME/}"
    fi

    # room for what this makes: the LZ4 images are ~4 times their LZX size, ~250 MB more; a zip also unpacks
    need=300
    [ -z "$zip" ] || need=$((need + $(unzip -l "$zip" | tail -n 1 | awk '{ print int($1 / 1048576) }')))
    have=$(free_mb)
    [ "$have" -ge "$need" ] || fail "Not enough room in HOME: %s MB free, %s MB needed" "$have" "$need"

    if [ -n "$zip" ]; then
        say "Unpacking the zip..."
        rm -rf "$data/unzip" && mkdir -p "$data/unzip" &&
            run unzip -q -o "$zip" '*StardewValley.exe' '*.dll' '*.dll.config' 'Content/*' '*/Content/*' -x '__MACOSX/*' \
                -d "$data/unzip" ||
            { rm -rf "$data/unzip"; fail "The zip could not be unpacked: is it whole?"; }
        exe=$(find "$data/unzip" -type f -name StardewValley.exe | sed -n 1p)
    else
        say "Moving the game into the app..."
    fi
    take "${exe%/*}" || fail "Could not move the game: is HOME full?"
    rm -rf "$data/unzip"
fi

v=$(version "$work/StardewValley.exe")
[ "$v" = "$TESTED" ] || say "Version %s of the game; the port is tested with %s" "${v:-?}" "$TESTED"

say "Building the port's patches against your game..."
run build_patches "$work" || fail "The patches don't build against this version of the game: see HOME/logs/stardew-import.log"

# an LZ4 image (from an earlier run) can't be read for it, so the icon from before stays
xnb=$work/Content/Minigames/TitleButtons.xnb
if [ -f "$xnb" ]; then
    say "Making the icon from the title logo..."
    run mono "$app/SdvIcon.exe" "$xnb" "$data/icon.new.png" && mv -f "$data/icon.new.png" "$data/icon.png"
    rm -f "$data/icon.new.png"
fi

say "Repacking the game's images for a faster start (several minutes)..."
run mono "$app/SdvXnb.exe" "$work/Content" || fail "Repacking failed: see HOME/logs/stardew-import.log"

# Mono's CodeDom writes the serializers' C# to TMPDIR: the card, not /tmp, which is RAM
say "Making the save serializers (several minutes)..."
mkdir -p "$data/tmp"
(cd "$work" && export TMPDIR="$data/tmp" MONO_PATH="$MONO_PATH:$work" && run mono "$app/SdvXmlGen.exe" "$work") &&
    ls "$work"/StardewValley.XmlSerializers.dll > /dev/null 2>&1 ||
    { rm -rf "$data/tmp"; fail "The save serializers failed: see HOME/logs/stardew-import.log"; }
rm -rf "$data/tmp"

rm -rf "$game" && rm -f "$work/.copied" && mv "$work" "$game" || fail "Could not move the game: is HOME full?"
[ ! -f "$data/icon.png" ] || cp -f "$data/icon.png" "$app/icon.png"
echo "$v" > "$data/ready"
say "Stardew Valley is ready: open it in the Games tab"
if [ -n "$zip" ]; then
    rm -f "$zip" && say "The zip was removed: the game is in the app now"
elif [ -n "$exe" ]; then
    left=${exe#$HOME/}
    left=${left%%/*}
    [ -d "$HOME/$left" ] && say "What is left in %s isn't needed any more and can be deleted" "$left"
fi
finish 0
