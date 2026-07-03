#!/bin/bash
# dictate.sh — core dictation pipeline: audio file in, polished text out.
#
#   Stage 1: WAV -> raw transcript   (whisper.cpp, large-v3-turbo, Metal)
#   Stage 2: raw -> polished text    (Ollama + cleanup-prompt.txt)
#
# Usage: dictate.sh <audio.wav>
# The last raw and cleaned transcripts are saved to last-raw.txt /
# last-clean.txt for debugging and prompt tuning.

set -euo pipefail
export PATH="/opt/homebrew/bin:$PATH"

DIR="$(cd "$(dirname "$0")" && pwd)"
WAV="${1:?usage: dictate.sh <audio.wav>}"

WHISPER_MODEL="$DIR/models/ggml-large-v3-turbo.bin"
CLEANUP_MODEL="gemma2:9b"

# The dictionary biases BOTH stages: whisper hears these terms more readily,
# and the cleanup LLM knows their canonical spelling/casing.
DICT="$(paste -sd ', ' "$DIR/dictionary.txt")"

# ---- Stage 1: speech -> raw text ----------------------------------------
# Silero VAD pre-filters the audio so whisper only decodes actual speech —
# without it, whisper hallucinates text ("Thank you.") on silence.
# speech-pad widens each detected speech region so word starts aren't clipped.
# --prompt seeds whisper's decoder with the domain vocabulary.
RAW=$(whisper-cli -m "$WHISPER_MODEL" -f "$WAV" --no-timestamps \
        --vad --vad-model "$DIR/models/ggml-silero-v5.1.2.bin" \
        --vad-speech-pad-ms 250 \
        --prompt "Glossary: $DICT." 2>/dev/null)
printf '%s\n' "$RAW" > "$DIR/last-raw.txt"

# Nothing said? Stop here — don't hand the LLM an empty page to imagine on.
if ! printf '%s' "$RAW" | grep -q '[^[:space:]]'; then
  : > "$DIR/last-clean.txt"
  exit 0
fi

# ---- Stage 2: raw text -> polished text ----------------------------------
# The prompt is cleanup-prompt.txt with the raw transcript appended.
# temperature 0 = deterministic output, no creative liberties.
# Dictionary goes in one-per-line: as a comma list the model tends to
# "autocomplete" adjacent terms into the text (tested; see project notes).
PROMPT="$(cat "$DIR/cleanup-prompt.txt")

Domain terms (exact spelling and casing, one per line):
$(cat "$DIR/dictionary.txt")

Raw transcript:
$RAW"

CLEAN=$(jq -n --arg model "$CLEANUP_MODEL" --arg prompt "$PROMPT" \
          '{model: $model, prompt: $prompt, stream: false,
            keep_alive: "60m",
            options: {temperature: 0}}' \
        | curl -s http://localhost:11434/api/generate -d @- \
        | jq -r '.response')

# Trim leading/trailing whitespace the LLM sometimes adds.
CLEAN="$(printf '%s' "$CLEAN" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

printf '%s\n' "$CLEAN" > "$DIR/last-clean.txt"
printf '%s' "$CLEAN"
