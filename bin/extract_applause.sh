#!/usr/bin/env bash
# Extract the middle 3 seconds of "Stadium Crowd Applause" from iMovie.app
# and install it as ~/Library/Sounds/Applause.aiff so macOS notifications can
# use it via soundName="Applause".
#
# This script never ships audio. It only operates on files already present
# on your machine (Apple's iLife Sound Effects bundled with iMovie). If you
# do not have iMovie installed, install it from the Mac App Store first
# (free).
set -euo pipefail

SRC="/Applications/iMovie.app/Contents/Resources/iLife Sound Effects/People/Stadium Crowd Applause.caf"
TMP_WAV="/tmp/_cda_applause_full.wav"
DST="${HOME}/Library/Sounds/Applause.aiff"

green() { printf "\033[32m%s\033[0m\n" "$1"; }
red()   { printf "\033[31m%s\033[0m\n" "$1"; }

if ! [[ -f "$SRC" ]]; then
  red "iMovie sound effects not found:"
  red "  $SRC"
  red "Install iMovie from the Mac App Store, then re-run this script."
  exit 1
fi

if ! command -v sox >/dev/null 2>&1; then
  red "sox required. Install with: brew install sox"
  exit 1
fi

mkdir -p "${HOME}/Library/Sounds"

# .caf uses AAC encoding which sox cannot read directly; transcode first.
afconvert -f WAVE -d LEI16 "$SRC" "$TMP_WAV"

# Trim 3 seconds starting at 5.5s — the most energetic middle segment of
# the 14.17s original.
sox "$TMP_WAV" "$DST" trim 5.5 3

rm -f "$TMP_WAV"

green "✓ Installed: $DST (3s)"
green "  Update ~/.config/coding-done-alert/config.json to use it:"
green "    \"sound\": { \"file\": \"~/Library/Sounds/Applause.aiff\" }"
