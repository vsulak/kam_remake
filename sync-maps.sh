#!/usr/bin/env bash
set -euo pipefail

# Sync playable content (maps, campaigns, tutorials) from the kam_remake_maps repository
# into the project root, where the engine looks for it (ExeDir = project root).
#
# This mirrors what the official GameBuilder does on Windows
# (Utils/GameBuilder (from kp-wiki)/KM_BuilderKMR.pas, Step11_ArrangeFolder):
# it copies Campaigns/, Maps/, MapsMP/ and Tutorials/ straight out of the maps repo.
#
# Those four directories are gitignored here — they are content, not source.

MAPS_REPO="${KAM_MAPS_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/kam_remake_maps}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WITH_EXTRA=0
DO_PULL=0
DRY_RUN=0

usage() {
  cat <<EOF
Usage: ./sync-maps.sh [options]

Copies playable content from the kam_remake_maps repo into the project root.

Options:
  --extra      Also install the non-shipping map sets:
                 MapsGA, MapsDev        -> Maps/
                 CampaignsCommunity     -> Campaigns/
               (the engine only scans Maps/ MapsMP/ MapsDL/ Tutorials/ Campaigns/,
                so these have to be merged in to be visible)
  --pull       git pull the maps repo before syncing
  --dry-run    Show what would be copied, copy nothing
  -h, --help   This help

Environment:
  KAM_MAPS_REPO   Path to the kam_remake_maps checkout
                  (default: ../kam_remake_maps relative to this script)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --extra)   WITH_EXTRA=1 ;;
    --pull)    DO_PULL=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

if [[ ! -d "$MAPS_REPO" ]]; then
  cat >&2 <<EOF
Error: maps repository not found at $MAPS_REPO

Clone it next to this repo:
  git clone https://github.com/reyandme/kam_remake_maps.git "$MAPS_REPO"

Or point KAM_MAPS_REPO at an existing checkout.
EOF
  exit 1
fi

if [[ $DO_PULL -eq 1 ]]; then
  echo "==> Pulling $MAPS_REPO"
  git -C "$MAPS_REPO" pull --ff-only
fi

# .mi files are the engine's mission-info cache; they are regenerated on demand and
# a stale one from another build shows wrong data in the map list.
RSYNC_OPTS=(-a --exclude '.git' --exclude '*.mi' --exclude 'thumbs.db' --exclude 'descript.ion')
[[ $DRY_RUN -eq 1 ]] && RSYNC_OPTS+=(--dry-run --itemize-changes)

sync_dir() { # $1 = source subdir in maps repo, $2 = destination subdir in project root
  local src="$MAPS_REPO/$1/" dst="$ROOT/$2/"
  if [[ ! -d "$MAPS_REPO/$1" ]]; then
    echo "    skip $1 (not present in maps repo)"
    return
  fi
  echo "    $1 -> $2/"
  mkdir -p "$dst"
  rsync "${RSYNC_OPTS[@]}" "$src" "$dst"
}

echo "==> Syncing from $MAPS_REPO"
echo "    into $ROOT"
echo

echo "==> Shipping content"
sync_dir Campaigns Campaigns
sync_dir Maps      Maps
sync_dir MapsMP    MapsMP
sync_dir Tutorials Tutorials

if [[ $WITH_EXTRA -eq 1 ]]; then
  echo
  echo "==> Extra content (merged into the engine's folders)"
  sync_dir MapsGA             Maps
  sync_dir MapsDev            Maps
  sync_dir CampaignsCommunity Campaigns
fi

echo
if [[ $DRY_RUN -eq 1 ]]; then
  echo "Dry run — nothing was copied."
else
  for d in Campaigns Maps MapsMP Tutorials; do
    printf '    %-10s %s entries\n' "$d" "$(ls "$ROOT/$d" 2>/dev/null | wc -l | tr -d ' ')"
  done
  echo
  echo "Done. Run ./KaM_Remake to play."
fi
