#!/usr/bin/env bash
set -euo pipefail

# Build KaM Remake for macOS (Apple Silicon / aarch64)
# Requirements: fpc, lazarus-src, libvorbis, libogg, openssl@3 (via Homebrew)
# Full explanation: Docs/Readme/building-macos.md

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FPC="${FPC:-/usr/local/bin/fpc}"
LAZARUS_SRC="${LAZARUS_SRC:-/opt/homebrew/opt/lazarus-src}"
HOMEBREW_LIB="${HOMEBREW_LIB:-/opt/homebrew/lib}"

DO_CLEAN=0
CHECK_ONLY=0

usage() {
  cat <<EOF
Usage: ./build-macos.sh [options]

Options:
  --clean       Remove all .ppu/.o build artifacts before compiling.
                Needed after editing units — incremental rebuilds can trigger
                FPC internal error 200611031 (see building-macos.md).
  --check       Run the prerequisite checks and exit without compiling.
  -h, --help    This help

Environment overrides:
  FPC            fpc binary          (default: /usr/local/bin/fpc)
  LAZARUS_SRC    Lazarus source tree (default: /opt/homebrew/opt/lazarus-src)
  HOMEBREW_LIB   Homebrew lib dir    (default: /opt/homebrew/lib)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean)   DO_CLEAN=1 ;;
    --check)   CHECK_ONLY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
fail=0
note() { echo "  $*"; }
err()  { echo "  ERROR: $*" >&2; fail=1; }

echo "==> Checking prerequisites"

if [[ -x "$FPC" ]]; then
  note "fpc          $("$FPC" -iV) at $FPC"
else
  err "fpc not found at $FPC — install with: brew install fpc"
fi

if [[ -d "$LAZARUS_SRC/lcl/units/aarch64-darwin" ]]; then
  note "lazarus-src  $LAZARUS_SRC"
else
  err "Lazarus LCL units not found under $LAZARUS_SRC — install with: brew install lazarus-src"
fi

if [[ -f "$HOMEBREW_LIB/libvorbisfile.dylib" ]]; then
  note "oggvorbis    $HOMEBREW_LIB"
else
  err "libvorbisfile not found in $HOMEBREW_LIB — install with: brew install libvorbis libogg"
fi

# PascalScript is a git submodule and is on the unit search path below; a fresh
# clone without --recursive leaves it empty and the build fails deep in uses clauses.
if [[ -f "$ROOT/src/ext/pascalscript_submodule/Source/uPSCompiler.pas" ]]; then
  note "submodules   initialised"
else
  err "src/ext/pascalscript_submodule is empty — run: git submodule update --init --recursive"
fi

# openssl@3 is a runtime-only dependency (multiplayer server list). Missing it does
# not break the build or the game, it just silently disables SSL.
if [[ -d /opt/homebrew/opt/openssl@3/lib ]]; then
  note "openssl@3    present (multiplayer SSL enabled)"
else
  note "openssl@3    MISSING — runtime only; SSL will be disabled. brew install openssl@3"
fi

[[ $fail -eq 0 ]] || { echo; echo "Prerequisites missing, aborting." >&2; exit 1; }

if [[ $CHECK_ONLY -eq 1 ]]; then
  echo
  echo "All build prerequisites satisfied."
  exit 0
fi

# ---------------------------------------------------------------------------
# Clean
# ---------------------------------------------------------------------------
if [[ $DO_CLEAN -eq 1 ]]; then
  echo "==> Cleaning build artifacts"
  find "$ROOT/src" \( -name '*.ppu' -o -name '*.o' \) -delete
  rm -f "$ROOT/KaM_Remake.o" "$ROOT/KaM_Remake.or"
fi

# ---------------------------------------------------------------------------
# Compile
# ---------------------------------------------------------------------------
echo "==> Compiling"
cd "$ROOT"

"$FPC" \
  -Mobjfpc -Sh -Tdarwin -Paarch64 -dFPC -dNO_MUSIC \
  \
  -Fu"$LAZARUS_SRC/lcl/units/aarch64-darwin/" \
  -Fu"$LAZARUS_SRC/lcl/units/aarch64-darwin/cocoa/" \
  -Fu"$LAZARUS_SRC/components/freetype/lib/aarch64-darwin/" \
  -Fu"$LAZARUS_SRC/components/lazutils/lib/aarch64-darwin/" \
  -Fu"$LAZARUS_SRC/components/opengl/lib/aarch64-darwin/cocoa/" \
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
  -Fl"$HOMEBREW_LIB" \
  -k"-lvorbisfile -lvorbis -logg" \
  -k"-no_objc_relative_method_lists" \
  \
  KaM_Remake.lpr

# ---------------------------------------------------------------------------
# Post-build: warn about missing playable content
# ---------------------------------------------------------------------------
echo
echo "==> Built $ROOT/KaM_Remake"

missing=()
for d in Campaigns Maps MapsMP Tutorials; do
  [[ -d "$ROOT/$d" ]] || missing+=("$d")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo
  echo "Note: missing playable content (${missing[*]})."
  echo "      The game will reach the main menu but every map start will fail."
  echo "      Install it with: ./sync-maps.sh"
fi
