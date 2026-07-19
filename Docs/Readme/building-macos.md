# Building KaM Remake on macOS (Apple Silicon)

This guide covers compiling and linking KaM Remake for macOS on Apple Silicon (aarch64) using Free Pascal Compiler and Lazarus LCL Cocoa.

## Quick start

```bash
git clone https://github.com/reyandme/kam_remake.git
cd kam_remake
git submodule update --init --recursive          # PascalScript is required to compile
git clone https://github.com/reyandme/kam_remake_maps.git ../kam_remake_maps

brew install fpc lazarus-src libvorbis libogg openssl@3

./build-macos.sh --check     # verify prerequisites
./build-macos.sh             # compile  (--clean for a full rebuild)
./sync-maps.sh               # install maps/campaigns/tutorials
./KaM_Remake
```

You still need `data/` from a KaM Remake release — see [Where the assets come from](#where-the-assets-come-from).

## Relation to the official compilation guide

The upstream wiki pages ([ProjectCompilation](https://github.com/reyandme/kam_remake/wiki/ProjectCompilation), [Building the project](https://github.com/reyandme/kam_remake/wiki/Building-the-project)) describe a **Windows + Delphi 10.3** flow and state outright that the project cannot be built on Lazarus. This document is the macOS/FPC counterpart. Mapping of the wiki's steps onto this port:

| Wiki step (Windows/Delphi) | On macOS/FPC |
|---|---|
| 1. Clone repo, update submodules | Same — `git submodule update --init --recursive`. `src/ext/pascalscript_submodule` is on the unit search path; without it the build fails deep inside `uses` clauses. `build-macos.sh --check` verifies this. |
| 2. Copy `data` from the original KaM install | Same requirement. See [Where the assets come from](#where-the-assets-come-from). |
| 3. Copy folders from a KaM Remake install | Partly superseded — maps/campaigns/tutorials should come from the `kam_remake_maps` repo via `./sync-maps.sh`. `data/`, `Sounds/`, `Music/` still come from a release. |
| 4. Revert downgraded files | Same caveat: copying a release over the checkout can overwrite tracked files. Check `git status` and `git checkout --` anything you did not mean to change. |
| 5. Enable `DBG_SKIP_SECURE_AUTH` | **Not needed.** `KaM_Remake.inc` already forces it on under `{$IFDEF FPC}` — `KM_NetAuthSecure` is Delphi-only. Do not edit the `.inc`. |
| 6. Disable `USE_MAD_EXCEPT` | **Not needed.** It lives inside `{$IFDEF WDC}` and is never defined on FPC. |
| 7. Pack sprites with RXXPacker | **Not available on macOS** — see [Sprites and RXXPacker](#sprites-and-rxxpacker). |
| 8. Disable `USE_VIRTUAL_TREEVIEW` | **Not needed.** Also `{$IFDEF WDC}`-only. |
| 9. Open `KaMProjectGroup.groupproj` in Delphi | Replaced by `./build-macos.sh`. |
| 10. Pre-commit hook for revision numbers | Optional, unchanged (`.git/hooks/pre-commit`, writes `KM_Revision.inc`). |
| `bat\make_beta_and_installer.bat` (release build) | No macOS equivalent. The release pipeline (`Utils/GameBuilder`, madExcept patching, Inno Setup, Linux dedicated servers) is Windows-only and additionally needs the private `kam_remake_resources` / `kam_remake_private` repos. |

**In short:** none of the `KaM_Remake.inc` edits the wiki asks for apply here — every one of them is already conditional on the compiler. The two things the wiki has that our flow was genuinely missing were the **submodule init** and a defined source for **playable content**; both are now handled by the scripts above.

## Requirements

| Tool | Version | Notes |
|---|---|---|
| FPC | 3.2.2+ | Install via Homebrew: `brew install fpc` |
| Lazarus | 3.x | Source needed for LCL units: `brew install lazarus-src` |
| Homebrew | any | For OggVorbis libraries |
| Xcode Command Line Tools | any | Provides `ld`, SDK headers |

### Homebrew dependencies

```bash
brew install libvorbis libogg openssl@3
```

`openssl@3` is required at runtime for the HTTP client (multiplayer server list). Without it, SSL is silently disabled but the app still runs.

Sound (SFX) uses the system `OpenAL.framework` — deprecated by Apple since macOS 10.15 but still shipped as of macOS 26.5, so no Homebrew package is needed. If Apple ever removes it, the fallback is `brew install openal-soft` plus pointing `callibname` in `src/ext/openal.pas` at the openal-soft dylib.

### Paths assumed by this guide

| Path | Contents |
|---|---|
| `/usr/local/bin/fpc` | FPC compiler binary |
| `/opt/homebrew/opt/lazarus-src` | Lazarus source + prebuilt LCL units |
| `/opt/homebrew/lib` | OggVorbis dylibs |

## Build Path Status (verified 2026-07-15, macOS 26.5.2)

| Path | Status |
|---|---|
| `./build-macos.sh` (direct FPC) | ✅ working — canonical build path |
| `lazbuild KaM_Remake.lpi` | ❌ broken — homebrew lazbuild 4.99 crashes (`EAccessViolation` in `FORMS.PP`) while loading this project; `--version` and `.lpk` package builds work |
| Lazarus IDE (F9) | ⚠️ untested on macOS 26; the `.lpi` lacks `-dNO_MUSIC`, the `-k` linker flags below, and a LazOpenGLContext package requirement — add them in Project Options before an IDE build |

## Compiler Defines

The macOS build requires two defines:

| Define | Purpose |
|---|---|
| `FPC` | Gates FPC-compatible code paths throughout the codebase |
| `NO_MUSIC` | Disables the music subsystem (not yet ported to macOS) |

## Build Command

Use the script — it runs prerequisite checks first and reports precisely which one failed:

```bash
./build-macos.sh            # incremental build
./build-macos.sh --clean    # wipe .ppu/.o first (see ICE note under Troubleshooting)
./build-macos.sh --check    # verify prerequisites only, do not compile
```

`FPC`, `LAZARUS_SRC` and `HOMEBREW_LIB` can be overridden as environment variables if your install differs from the paths above.

The script is a thin wrapper around this invocation:

```bash
/usr/local/bin/fpc \
  -Mobjfpc -Sh -Tdarwin -Paarch64 -dFPC -dNO_MUSIC \
  \
  -Fu/opt/homebrew/opt/lazarus-src/lcl/units/aarch64-darwin/ \
  -Fu/opt/homebrew/opt/lazarus-src/lcl/units/aarch64-darwin/cocoa/ \
  -Fu/opt/homebrew/opt/lazarus-src/components/freetype/lib/aarch64-darwin/ \
  -Fu/opt/homebrew/opt/lazarus-src/components/lazutils/lib/aarch64-darwin/ \
  -Fu/opt/homebrew/opt/lazarus-src/components/opengl/lib/aarch64-darwin/cocoa/ \
  \
  -Fusrc -Fusrc/ai -Fusrc/common -Fusrc/controls -Fusrc/forms \
  -Fusrc/game -Fusrc/gui -Fusrc/hands -Fusrc/houses -Fusrc/media \
  -Fusrc/net -Fusrc/render -Fusrc/res -Fusrc/scripting -Fusrc/settings \
  -Fusrc/terrain -Fusrc/units -Fusrc/utils -Fusrc/utils/algorithms \
  -Fusrc/utils/io -Fusrc/utils/method_parser \
  -Fusrc/minimap -Fusrc/mission -Fusrc/navmesh -Fusrc/pathfinding \
  -Fusrc/perflog -Fusrc/maped \
  -Fusrc/ai/newAI -Fusrc/game/gip -Fusrc/game/misc -Fusrc/game/notifications \
  -Fusrc/gui/pages_common -Fusrc/gui/pages_game -Fusrc/gui/pages_menu \
  -Fusrc/gui/pages_maped -Fusrc/gui/pages_maped/menu \
  -Fusrc/gui/pages_maped/player -Fusrc/gui/pages_maped/mission \
  -Fusrc/gui/pages_maped/terrain -Fusrc/gui/pages_maped/town \
  -Fusrc/net/http -Fusrc/net/other \
  -Fusrc/ext -Fusrc/ext/OggVorbis -Fusrc/ext/LNet -Fusrc/ext/BGRABitmap \
  -Fusrc/ext/pascalscript_submodule/Source \
  -Fusrc/units/tasks -Fusrc/units/actions \
  \
  -k"-framework OpenGL -framework UserNotifications" \
  -Fl/opt/homebrew/lib \
  -k"-lvorbisfile -lvorbis -logg" \
  -k"-no_objc_relative_method_lists" \
  \
  KaM_Remake.lpr
```

## Key Linker Flags Explained

### `-k"-framework OpenGL -framework UserNotifications"`

The Cocoa LCL backend uses OpenGL for rendering and UserNotifications for system tray alerts. FPC does not automatically link these frameworks on macOS.

### `-Fl/opt/homebrew/lib -k"-lvorbisfile -lvorbis -logg"`

OggVorbis audio decoding libraries installed via Homebrew. `-Fl` adds the Homebrew lib directory to the linker search path.

### `-k"-no_objc_relative_method_lists"` — Required on macOS 26+

**This flag is essential when linking with macOS 26's `ld` (ld-1266 or later).**

FPC 3.2.2 generates Objective-C method lists that place multiple method lists under a single Mach-O section atom (`ltmp5`). The ld-1266 linker introduced strict validation of ObjC method list atoms: it checks that all pointer fixups within an atom fall within the bounds declared by the method list `count` field. Because FPC groups multiple method lists into one atom without individual symbol boundaries, ld-1266 sees fixups "beyond" the declared count and aborts with:

```
ld: malformed method list atom 'ltmp5' (...cocoawsextctrls.o),
    fixups found beyond the number of method entries
```

Passing `-no_objc_relative_method_lists` disables the relative method list transformation (and its associated validation), allowing the link to succeed. This flag has no negative effect at runtime — the generated binary functions correctly.

> **Note**: This workaround is not needed with FPC 3.3.1+, which generates individual symbols per method list and passes ld-1266 validation without the flag.

## Expected Output

A successful clean build produces:

```
495022 lines compiled, ~28 sec
KaM_Remake  (Mach-O 64-bit executable arm64, ~32 MB)
```

Warnings about `building for macOS-11.0, but linking with dylib ... built for newer version 26.0` are harmless — the binary runs on macOS 26.

## Running the Game — Data Setup

The binary derives its data directory from its own location (`ExeDir = ExtractFilePath(ParamStr(0))`), i.e. the **project root**. There is no data-path setting or environment override. All game content must therefore live at the root, next to the binary.

### Where the assets come from

None of the game content is in this repository — `Maps/`, `MapsMP/`, `Campaigns/`, `Tutorials/`, `data/Sprites/`, `data/sfx/` and parts of `data/gfx/` are all gitignored. This mirrors how the official Windows release is assembled (`Utils/GameBuilder (from kp-wiki)/KM_BuilderKMR.pas`, `Step11_ArrangeFolder`), which pulls each piece from a different source:

| Directory | Source | How to obtain |
|---|---|---|
| `Maps/` `MapsMP/` `Campaigns/` `Tutorials/` | **`kam_remake_maps` repo** | `./sync-maps.sh` |
| `data/defines/` `data/gfx/` `data/text/` `data/cursors/` | this repo + original KaM install | mostly tracked; `houses.dat`, `unit.dat`, `pattern.dat`, `*.lbm`, `*.bbm` come from the original game's `data/` |
| `data/Sprites/` (`*.rxx`) | packed from `.rx` sources by RXXPacker | not reproducible on macOS — copy from a KaM Remake release, see below |
| `data/sfx/` | original KaM install (`sounds.dat`, `speech.*`) | copy from the original game |
| `Sounds/` `Music/` | KaM Remake release | copy from a release (`Music/` is unused here — the build sets `NO_MUSIC`) |
| campaign videos, `Installer/CheckKaM.iss`, `KM_NetAuthSecure.pas` | private `kam_remake_private` repo | not publicly available; the game runs fine without them |

### Using the `kam_remake_maps` repository

[`kam_remake_maps`](https://github.com/reyandme/kam_remake_maps) is the upstream content repository — it tracks maps and campaigns on the same master as the engine, so it stays in sync with the current mission format. This is the right source for playable content; a copy from an old release is not.

```bash
git clone https://github.com/reyandme/kam_remake_maps.git ../kam_remake_maps
./sync-maps.sh                  # copies the four shipping directories into the project root
./sync-maps.sh --pull           # git pull the maps repo first
./sync-maps.sh --extra          # also install MapsGA, MapsDev, CampaignsCommunity
./sync-maps.sh --dry-run        # show what would be copied
```

Point `KAM_MAPS_REPO` at the checkout if it is not at `../kam_remake_maps`.

Only four of the repo's directories are shipped, matching what GameBuilder copies:

| Maps repo directory | Shipped? | Notes |
|---|---|---|
| `Campaigns/` | ✅ | 11 campaigns (the 5 official ones plus community campaigns) |
| `Maps/` | ✅ | 42 singleplayer maps |
| `MapsMP/` | ✅ | 212 multiplayer maps |
| `Tutorials/` | ✅ | 2 tutorials |
| `MapsGA/` `MapsDev/` | ➖ | Golden Age / developer test maps — `--extra` merges them into `Maps/` |
| `CampaignsCommunity/` | ➖ | `--extra` merges into `Campaigns/` |
| `CampaignDrafts/` `MapsRemoved/` | ❌ | unfinished / retired content |

The extra sets have to be *merged into* `Maps/` and `Campaigns/` rather than copied as-is, because the engine only scans the fixed folder names in `KM_Defaults.pas:552-558` (`Maps`, `MapsMP`, `MapsDL`, `Tutorials`, `Campaigns`) — a top-level `MapsGA/` directory would simply be invisible.

The sync excludes `*.mi` files: those are the engine's mission-info cache, regenerated on demand, and a stale one from another build shows wrong data in the map list.

> Switching from a 2014-era release's maps to this repo also clears the `Error loading map TXT file: List index (7) out of bounds` warnings — those come from the old map metadata format, not from a bug.

### Sprites and RXXPacker

Step 7 of the upstream guide packs `.rx` sprite sources into `data/Sprites/*.rxx` with `Utils/RXXPacker`. **This does not work on macOS**, for two independent reasons:

1. `Utils/RXXPacker/RXXPackerConsole.pas` unconditionally `uses Windows` and builds paths with backslashes, and only the Delphi entry point (`RXXPacker.dpr`) wires up console mode — the FPC entry point (`RXXPacker.lpr`) is GUI-only.
2. The `.rx` sources are not public. GameBuilder reads them from `kam_remake_private/SpriteResource/` and `kam_remake_private/SpriteInterp/Output/`.

So on macOS, `data/Sprites/` must be copied from a built KaM Remake release. Take it from a **recent** one — see the layout warning below.

### Sprite data must match the engine's RXX layout

`data/Sprites/*.rxx` from the original 2014 retail release use an **older on-disk record layout** (Integer pivots; no `SizeNoShadow`) than this engine revision expects (SmallInt pivots since 2021; `SizeNoShadow` for Units). Headerless (`rxxZero`, raw-zlib) files of both layouts are indistinguishable to the loader, so it silently mis-parses the old ones — producing garbage sprite sizes, huge phantom allocations, lost sprites, and **intermittent access violations** later in the run.

If sprites look wrong or the game AVs during/after load, check the file dates in `data/Sprites/`. Converting the 2014 files in place to the modern layout resolves it (originals preserved in `data/Sprites-orig-2014/`). The clean long-term fix is to use `data/` from a **recent KaM Remake beta** rather than the 2014 retail data.

### Playable content directories

The engine loads maps, campaigns and tutorials from these directories at the root:

```
Maps/  MapsMP/  Campaigns/  Tutorials/
```

If they are missing, the game runs to the main menu but every map/tutorial/campaign start fails with `Mission file ... could not be found` (a handled error dialog, no longer a crash — see porting notes below). Install them with `./sync-maps.sh` as described above.

Copying them out of an old release instead (e.g. a bundled `KaM Remake/` retail folder) also works, but gives you that release's map set — expect `Error loading map TXT file: ... List index (7) out of bounds` on map-list preview for maps in the pre-2015 metadata format. That is a handled per-map parse error, not a crash; those maps just show incomplete preview info.

`data/` and `Sounds/` are also required at the root. `Music/` is not — the build sets `NO_MUSIC`.

### macOS porting notes (access violations fixed)

Three macOS-specific AVs on the launch → menu → game-start path have been fixed; they are documented here in case similar symptoms recur:

- **Cursor on window focus** (`src/KM_System.pas`): custom cursors are not realized on Cocoa (`MakeCursors` is a no-op), so `SetCursor`/`GetCursor` must never assign `Screen.Cursor` to an unregistered custom index — the LCL Cocoa widgetset dereferences a nil `TCocoaCursor` in `TCursorHelper.SetCursorOnActive` when the window first becomes key. On `{$IFDEF DARWIN}` the cursor is tracked in a unit-level variable (not an instance field — `gSystem` is still nil during early resource loading).
- **Windows-only menu items on game start** (`src/forms/KM_FormMain.pas`): `GameStarted`/`GameEnded`/`SetExportGameStats` toggle native Windows menu/debug controls that are nil on Cocoa; their bodies are guarded with `{$IFDEF WDC}`.
- **Diagnostics** (`src/KM_Main.pas`): `Application.OnException` logs a raw backtrace for otherwise-invisible unhandled exceptions (FPC/macOS produces no `.ips` and no stderr under `open`). Symbolize offline with `atos` — do **not** build with `-g`/`-gl`, which make FPC 3.2.2 ICE on this project.

## Troubleshooting

### `Can't find unit KM_Xxx`
Add the missing subdirectory as a `-Fu` search path. All `src/` subdirectories must be listed explicitly — FPC does not recurse.

### `Undefined symbols: _ov_read` etc.
Missing OggVorbis link. Add `-Fl/opt/homebrew/lib -k"-lvorbisfile -lvorbis -logg"`.

### `Undefined symbols: _GLCOCOANSCONTEXT_$_...`
Missing OpenGL framework. Add `-k"-framework OpenGL"`.

### `malformed method list atom 'ltmp5'`
Missing `-k"-no_objc_relative_method_lists"`. Required on macOS 26 with ld-1266+.

### `Invalid dylib load` crash on startup (macOS 15+ / macOS 26+)

```text
abort() called
Invalid dylib load. Clients should not load the unversioned libssl dylib as it does not have a stable ABI.
```

macOS 15 (Sequoia) and later ship `/usr/lib/libssl.dylib` as a stub that immediately calls `abort()` when loaded, to prevent use of the unstable unversioned API. The LNet SSL layer tried this path first.

**Fix** (already applied in code): `openssl.pas` now tries Homebrew OpenSSL 3 at `/opt/homebrew/opt/openssl@3/lib/` first, and skips the unversioned `libssl.dylib` on Darwin entirely.

**Runtime requirement**: install Homebrew OpenSSL 3 so the library is present:

```bash
brew install openssl@3
```

Without it, SSL is silently unavailable but the app runs normally.

### FPC internal error 200611031
Two known triggers:
- `(Self = nil)` checks inside class helpers that also call virtual methods. Remove the nil check; use `Self is TKMXxx` instead.
- **Incremental rebuilds** after editing a unit can ICE in `KM_HandEntityHelper.pas` even without source changes there. Do a clean rebuild: `./build-macos.sh --clean`.

### `Can't find unit uPSCompiler` / PascalScript units missing
The `src/ext/pascalscript_submodule` submodule was not checked out. Run `git submodule update --init --recursive`, or `./build-macos.sh --check` to confirm.

### `EListError: List index exceeds bounds` during compilation
Caused by generic `TProc<T1,T2>` in the interface section of a unit. Replace with a concrete `procedure(...) of object` type alias guarded by `{$IFDEF FPC}`.
