Stardew Valley for goodluckOS, as an app for the App Installer. The zip is the port only, with nothing of the game in it: it runs your own copy, from Steam's compatibility branch.

**You need** a GA36-MB with a goodluckOS that has the App Installer (System Settings > System > App Installer), about 1.2 GB free on its HOME for the first start (750 MB once it is done), and Stardew Valley on Steam, switched to the compatibility branch (Properties > Betas > compatibility), in its macOS or Linux version: the one with `StardewValley.exe`. The Windows version doesn't run yet.

1. Copy `StardewValley-*.zip` to the `apps` folder of the console's HOME (over USB, where the console shows up as a drive, or with the card in a card reader) and install it in the App Installer. Stardew Valley shows up in the Games tab.
2. Copy your game's folder to the root of HOME, as it is or as a zip of it. In Steam, Manage > Browse local files opens that folder. One zip goes over USB much faster than the game's thousands of files.
3. Open Stardew Valley on the console. The first time, it takes your copy into the app and gets it ready for the console, on a screen that shows how far it has got: about 15 minutes on the GA36-MB, once. Then the game starts, and from then on it starts straight away.

Your saves stay in `HOME/.config/StardewValley`, apart from the app. A newer zip updates the port the same way and keeps your game; uninstalling the app removes its copy of the game but not your saves. On the GA36-MB (Allwinner A33, 512 MB of RAM) the farm runs at about 19 FPS, the title screen comes up in about 20 seconds and a save loads in about a minute. So far it has been tested on one console.

How it works, how to build it, and the credits: [README](https://github.com/alvesmaicon/glOSports-stardew#readme).
