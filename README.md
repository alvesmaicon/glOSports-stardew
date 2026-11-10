# Stardew Valley for goodluckOS

![Stardew Valley on the console: the farm on a rainy morning](docs/stardew-valley.png)

Stardew Valley, natively on the GA36-MB (Allwinner A33, 32-bit ARM, Mali-400, 512 MB of RAM) under [goodluckOS](https://github.com/CodeZombie/goodluckOS). The PC build from Steam's "compatibility" branch (1.6.15) is a .NET Framework program, so it runs on Mono, built here for 32-bit ARM. PortMaster's port supplies the rest: JohnnyonFlame's MonoGame, which streams the music from the card instead of RAM, and gl4es, which turns the game's OpenGL into OpenGL ES 2. This port's patches cut work the game repeats every frame, and the save serializers are generated ahead of time. About 19 FPS on the farm, the title screen in ~20 s, a save loaded in ~55 s.

**Nothing of the game is in this repository.** You supply your own copy: Stardew Valley on Steam, switched to the compatibility branch (Properties > Betas > compatibility), in its macOS or Linux version (the one with `StardewValley.exe`). Tested with the macOS one.

Status: work in progress, tested on one GA36-MB (A33) only.

## Building and installing

The port is built on a PC with Docker (Intel or Apple Silicon; on a Mac, Colima or Docker Desktop). `SDV_GAME` is the game's folder; Steam's on a Mac is the default. The result holds your game's files, so it is for your own console only.

```sh
./build.sh          # the port in out/stardewvalley, its patches built against your game
./build.sh game     # your game's files in out/gamedata, the .xnb ones recompressed as LZ4
./build.sh xmlgen   # the save serializers, into out/gamedata
```

Copy both to the console's HOME partition (here with the card in a reader on a Mac, at `/Volumes/HOME`):

```sh
mkdir -p /Volumes/HOME/ports
cp -R out/stardewvalley /Volumes/HOME/ports/
cp -R out/gamedata/. /Volumes/HOME/ports/stardewvalley/gamedata/
dot_clean /Volumes/HOME
```

and add the entry in `out/apps.puppy-entry` to `HOME/apps.puppy` (the launcher reads it when it starts). The icon comes from your game's title logo, and the game follows the launcher's language. Log: `HOME/logs/stardew.log`.

## Layout

| | |
|---|---|
| `build.sh`, `Dockerfile` | the build, in the `glosports-stardew` image; downloads and build trees in the `stardew-work` volume |
| `stardew.sh` | starts the game on the console |
| `patches/` | the port's C#: JohnnyonFlame's game patches and loader with this port's changes, the CPU patches (`SpeedPatches.cs`), the serializer generator, the LZ4 recompressor and the icon maker |
| `native/` | the LZ4 shim for 32-bit ARM, a GSSAPI stub for Mono, an OpenAL tone check |
| `test/HelloMG.cs` | a MonoGame check without the game (`stardew.sh test`) |
| `tools/` | benchmarks: on the console over its serial port (`console.sh`), on the PC (`macbench.sh`, in its own image, `bench.Dockerfile`), and their readers |

## Credits

Stardew Valley is ConcernedApe's, and the copy is yours. The port is built on [PortMaster's](https://github.com/PortsMaster/PortMaster-New) port of the game: JohnnyonFlame's MonoGame with streamed audio (the MonoGame Team, Ms-PL) and his loader and game patches, [gl4es](https://github.com/ptitSeb/gl4es) by ptitSeb and Ryan Hileman (MIT), [Mono](https://www.mono-project.com/) (MIT, some parts BSD-3-Clause), [OpenAL Soft](https://github.com/kcat/openal-soft) (LGPL 2) and [lz4](https://github.com/lz4/lz4) (BSD-2-Clause). Their license files go into the port's folder.

## License

This repository is MIT ([LICENSE](LICENSE)). `patches/StardewPatches.cs` and `patches/SVLoader.cs` start from JohnnyonFlame's sources, under his BSD license ([licenses/LICENSE.JohnnyonFlame.txt](licenses/LICENSE.JohnnyonFlame.txt)).
