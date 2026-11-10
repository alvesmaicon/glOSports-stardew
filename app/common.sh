# common.sh: what stardew.sh and import.sh share, sourced in the app's folder. The player's game lives in data/game,
# which the App Installer keeps when the app is updated.
app=$(pwd)
data=$app/data
game=$data/game
export PATH=$app/mono/bin:$PATH
export LD_LIBRARY_PATH=$app/lib:$app/mono/lib
export MONO_PATH=$app/dlls:$app

# the sources that made data/StardewPatches.dll: an update of the app with other ones builds it again
patches_stamp() {
    cat "$app"/src/*.cs | cksum | cut -d ' ' -f 1
}

# StardewPatches.dll from src/, compiled against the game in $1 (default data/game)
build_patches() {
    _g=${1:-$game}
    mkdir -p "$data"
    rm -f "$data/StardewPatches.stamp"
    mcs -nologo -target:library -optimize+ -lib:"$_g" -lib:"$app/dlls" -r:"$_g/StardewValley.exe" -r:xTile.dll \
        -r:MonoGame.Framework.dll -r:0Harmony.dll -r:System.Xml -out:"$data/StardewPatches.dll" "$app"/src/*.cs &&
        patches_stamp > "$data/StardewPatches.stamp"
}

patches_current() {
    [ -f "$data/StardewPatches.dll" ] && [ "$(cat "$data/StardewPatches.stamp" 2>/dev/null)" = "$(patches_stamp)" ]
}

# Puppy's interface language (pt-BR, en...)
puppy_language() {
    sed -n 's/^language=//p' "$HOME/.config/puppy/settings" 2>/dev/null | tail -n 1
}
