# CLAUDE.md — KaM Remake

## Project Identity
Open-source remake of "Knights and Merchants" RTS. Language: **Delphi/Pascal** (Lazarus/FPC for macOS/Linux). Build: `KaM_Remake.lpr` (Lazarus) / `KaM_Remake.dpr` (Delphi). Compiler flags: `KaM_Remake.inc`.

## Naming Conventions
| Prefix | Meaning | Example |
|--------|---------|---------|
| `T` | Class/type | `TKMGame`, `TKMUnit` |
| `f` | Private field | `fOptions`, `fIsExiting` |
| `a` | Parameter | `aGameMode`, `aOwner` |
| `g` | Global singleton | `gGame`, `gRes`, `gLog` |
| `TKM` | Engine type | `TKMHandID`, `TKMUnitType` |

## Key Globals
- `gGame: TKMGame` — main game session
- `gGameApp: TKMGameApp` — app root
- `gRes: TKMResource` — all resources (sprites, fonts, sounds, units)
- `gLog: TKMLog` — logging
- `gSoundPlayer`, `gMusic` — audio
- `gResTexts` — translations
- All are nil before init; always nil-check before use.

## Source Map (`src/`)
```
game/         TKMGame — core loop, state, tick
game/gip/     Game Input Process — command routing, replays, multiplayer sync
ai/           City planning, army management
hands/        Player economies (TKMHand)
units/        Unit types and behaviors
houses/       Building mechanics
terrain/      Terrain system
render/       OpenGL rendering pipeline
res/          Resource loading (sprites, sounds, units, fonts)
scripting/    Pascal-based map scripting engine
net/          Multiplayer networking
mission/      Campaign/mission loading
controls/     Custom UI controls
gui/          Menu and in-game GUI
common/       Shared types, defaults, utilities (KM_Defaults.pas for constants)
ext/          Third-party: dglOpenGL, openal, OggVorbis, VerySimpleXML, PascalScript
media/        Audio/video playback
perflog/      Performance logging
settings/     App configuration
maped/        Map editor
pathfinding/  Pathfinding algorithms
navmesh/      Navigation mesh
utils/        Misc utilities
```

## Unit Structure Pattern
```pascal
unit KM_Foo;
{$I KaM_Remake.inc}   // always first — applies compiler directives
interface
uses ...
type
  TKMFoo = class
  private
    fField: Integer;
  public
    constructor Create(...);
    destructor Destroy; override;
  end;
implementation
uses ...
end.
```

## Compiler Flags (`KaM_Remake.inc`)
- `WDC` — Delphi compiler (Win32/Win64)
- `FPC` — Free Pascal / Lazarus
- `USE_MAD_EXCEPT` — crash reporting (WDC 32-bit only)
- `VIDEOS` — video playback (WDC only)
- `LOAD_GAME_RES_ASYNC` — async resource load (default on)
- `DBG_PERFLOG` — performance logging
- `DBG_RNG_SPY` — RNG spy for replay determinism
- `DBG_SKIP_SECURE_AUTH` — skip KM_NetAuthSecure (auto on FPC)
- `DEBUG` — general debug mode (off by default)
- Many Delphi warnings promoted to errors — do not introduce them.

## GIP System (Game Input Process)
All player commands flow through GIP (`src/game/gip/`). It:
- Converts UI actions → standardized commands (100+ cmd types)
- Records commands for replays
- Routes commands over network in multiplayer
- Base class: `TKMGameInputProcess`; variants: `_Single`, `_Multi`
- **Never bypass GIP** for game-state-changing actions — it breaks replays and MP sync.

## Memory Management
- Manual: `Free` / `FreeThenNil()` (no ARC, no GC)
- Entity base class `TKMEntity` provides UIDs
- Destructors call `inherited` at the end
- Worker threads via `TKMWorkerThreadHolder` for async saves

## Logging
```pascal
gLog.AddTime('message');     // timestamped
gLog.LogDebug('message');    // debug category
```
Log categories: default, delivery, commands, randomChecks, netConnection, netPacketCommand, debug.

## Code Rules
1. Always include `{$I KaM_Remake.inc}` as first line after `unit`.
2. 2-space indentation.
3. Nil-check globals before use (`if gGame <> nil then ...`).
4. Do not promote warnings to errors yourself — the `.inc` already handles this.
5. Game-state changes must go through GIP — never mutate state directly from UI.
6. No test framework exists — test manually or via replay consistency checks.

## Build

### macOS (FPC / LCL Cocoa)
- **Canonical build: `./build-macos.sh`** — runs prerequisite checks, then a direct FPC invocation with all unit paths, defines (`-dFPC -dNO_MUSIC`) and the macOS 26 linker flags. Clean build ≈ 495k lines / ~28 s. Full explanation: `Docs/Readme/building-macos.md`.
  - `--clean` wipes `.ppu`/`.o` first (needed after editing units — incremental rebuilds can ICE), `--check` verifies prerequisites without compiling.
- **Submodules are required.** `src/ext/pascalscript_submodule` is on the unit search path; a non-recursive clone fails deep inside `uses` clauses. `git submodule update --init --recursive`.
- **Do NOT edit `KaM_Remake.inc` for the macOS build.** The upstream wiki tells Windows users to toggle `DBG_SKIP_SECURE_AUTH`, `USE_MAD_EXCEPT` and `USE_VIRTUAL_TREEVIEW` by hand; all three are already compiler-conditional and correct on FPC.
- **From IDE:** Open `KaM_Remake.lpi` in Lazarus (F9 / Shift+F9). Caveat: the `.lpi` does not carry `-dNO_MUSIC`, the `-k` linker flags, or a LazOpenGLContext requirement — IDE builds need those added in Project Options first.
- **lazbuild: broken as of 2026-07-15** — homebrew lazbuild 4.99 crashes with `EAccessViolation` in `FORMS.PP` while loading `KaM_Remake.lpi` (`--version` and `.lpk` package builds work, so it is project-load specific). The old "stray `.ppu` in `lcl/interfaces/cocoa/`" fix does not apply (no strays present). Use `./build-macos.sh` instead.
  - FPC version: 3.2.2, target: aarch64-darwin. FPC binary: `/usr/local/bin/fpc`
  - Pre-compiled LCL cocoa units: `/opt/homebrew/opt/lazarus-src/lcl/units/aarch64-darwin/` (+ `cocoa/` subdir)
  - macOS 26 (ld-1266) requires linker flag `-no_objc_relative_method_lists` (already in the script; obsolete once FPC ≥ 3.3.1)

### Windows (Delphi)
- `bat/build_exe.bat` or msbuild on `KaM_Remake.dproj`

### Game assets (not in this repo)
All playable content is gitignored and comes from elsewhere — mirroring `Utils/GameBuilder (from kp-wiki)/KM_BuilderKMR.pas`, `Step11_ArrangeFolder`:

| Content | Source |
|---|---|
| `Maps/` `MapsMP/` `Campaigns/` `Tutorials/` | **`kam_remake_maps` repo** → `./sync-maps.sh` |
| `data/Sprites/*.rxx` | packed from private `.rx` sources; on macOS copy from a **recent** release |
| `data/sfx/`, parts of `data/gfx|defines/` | original KaM install |
| `Sounds/` | KaM Remake release (`Music/` unused — `NO_MUSIC`) |

- `./sync-maps.sh` — installs the four shipping dirs from `../kam_remake_maps` (override with `KAM_MAPS_REPO`). Flags: `--pull`, `--extra` (merges `MapsGA`/`MapsDev` into `Maps/`, `CampaignsCommunity` into `Campaigns/`), `--dry-run`.
- The engine only scans the fixed folder names in `KM_Defaults.pas:552-558` — `MapsGA/` etc. at top level are invisible, they must be merged in.
- RXXPacker (`Utils/RXXPacker`) is **Windows-only**: `RXXPackerConsole.pas` hard-requires the `Windows` unit, and the `.rx` sources live in the private repo.

### Build artifacts
- Gitignored: `.ppu`, `.o`, `.dcu`, `Logs/`, game data (sprites, sounds, maps, saves)
- Output binary: `KaM_Remake` (macOS) / `KaM_Remake.exe` (Windows) in project root
- `KaM_Remake.app/Contents/MacOS/KaM_Remake` is a symlink to the root binary — the bundle is always current after a rebuild

## Running / Debugging

### Launching the game (macOS)
```bash
cd /Users/viktorsulak/Projects/kam_remake
./KaM_Remake
# Or via the app bundle:
open KaM_Remake.app
```

### Log file location
The game writes one log per run to `Logs/` **in the project root** (next to the binary), even when launched via the app bundle:
```
Logs/KaM_<yyyy-mm-dd_hh-mm-ss-ms>.log
```
Tail the latest log while running: `tail -f "$(ls -t Logs/*.log | head -1)"`
(Settings live in `~/My Games/Knights and Merchants Remake/`; logs do NOT go there.)

### Runtime behavior worth knowing
- While the app is **unfocused**, async resource loading pauses — texture generation runs in `Application.OnIdle`, which App Nap throttles. A log going quiet right after "Main menu init done" means the app is unfocused, not hung; loading resumes on focus.
- A clean exit(0) with no shutdown lines in the log is the signature of the window being closed — the game logs nothing on a normal quit.

### Crash reports (macOS)
```
~/Library/Logs/DiagnosticReports/KaM_Remake-*.ips
```
Open with Console.app or `cat` — contains stack trace, signal, and thread info.

### Diagnostic logging strategy
When a crash happens with no clear stack trace (e.g. OOM), add `gLog.AddTime('checkpoint N')` calls around the suspected code path, rebuild, run, and check which checkpoint is last in the log. The gap between the last logged line and the crash timestamp (e.g. server-settings save in destructor) reveals where execution died.

## Testing
- No automated test framework. Test by running the game manually.
- Replay consistency: record a replay and play it back — any desync indicates non-deterministic state changes.
- For crash bugs: add `gLog.AddTime(...)` checkpoints, rebuild, repro the crash, read the log.

---

## Meta / Process Rules
- **Compact context often** — this codebase is large. Compact regularly to avoid running out of context mid-task.
- **Write lessons learned immediately** — after any correction, update `.claude/tasks/lessons.md` before moving on. Write rules that prevent the same mistake. Review at each session start.
- **Read before modifying** — always read a file before editing. Never guess at structure.
- **Verify memory before acting on it** — a memory naming a file/function is a claim it existed *when written*. Grep or Read to confirm before acting.

---

## Lessons Learned
- After ANY correction from the user: update `.claude/tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review `.claude/tasks/lessons.md` at session start for relevant context
