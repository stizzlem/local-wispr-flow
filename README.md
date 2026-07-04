# local-wispr-flow

A free, fully-local speech-to-text dictation tool for macOS that replaces
Wispr Flow. Double-tap Ctrl, talk, double-tap Ctrl again — polished text
appears at your cursor in whatever app is focused. 100% offline, $0/month.

## How it works

```
Double-tap Ctrl ──▶ ffmpeg records mic (16 kHz)
Double-tap Ctrl ──▶ whisper.cpp (large-v3-turbo + Silero VAD, Metal) ──▶ raw transcript
                    Ollama (gemma2:9b, temperature 0)                ──▶ polished text
                    Hammerspoon pastes it at the cursor
```

## Files

| File | Role |
|---|---|
| `dictate.sh` | The core pipeline: WAV in, polished text out (whisper → ollama) |
| `dictation.lua` | Hammerspoon glue: double-tap-Ctrl toggle, recording, feedback UI, paste |
| `cleanup-prompt.txt` | The LLM cleanup rules — edit to tune tone/behavior, takes effect immediately |
| `dictionary.txt` | Domain terms, one per line — biases what whisper hears AND enforces exact spelling in cleanup. Keep it one-per-line: a comma list makes the LLM autocomplete adjacent terms into the text |
| `BUILD-PROMPT.md` / `CONTEXT.md` | Original build prompt and decision log |
| `last-raw.txt` / `last-clean.txt` | (not committed) Debug output of the last dictation, per stage |

## Restore on a new Mac

1. Install the tools:
   ```bash
   brew install ollama whisper-cpp jq ffmpeg
   brew install --cask hammerspoon
   brew services start ollama
   ```
2. Clone this repo to `~/Fable5-Projects/local-wispr-flow/`.
3. Download the models (not in the repo — too big):
   ```bash
   cd ~/Fable5-Projects/local-wispr-flow
   curl -L -o models/ggml-large-v3-turbo.bin --create-dirs \
     https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin
   curl -L -o models/ggml-silero-v5.1.2.bin \
     https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin
   ollama pull gemma2:9b
   ```
4. Point Hammerspoon at the config:
   ```bash
   mkdir -p ~/.hammerspoon
   echo 'dofile(os.getenv("HOME") .. "/Fable5-Projects/local-wispr-flow/dictation.lua")' > ~/.hammerspoon/init.lua
   chmod +x dictate.sh
   open -a Hammerspoon
   ```
5. Grant permissions when prompted: **Accessibility** (hotkey + paste) and
   **Microphone** (first recording). Both under System Settings → Privacy & Security.
6. The mic is selected by name (`:MacBook Pro Microphone`). On different
   hardware, list devices with `ffmpeg -f avfoundation -list_devices true -i ""`
   and update `MIC_DEVICE` in `dictation.lua`. Use the name, not the index —
   indices reshuffle whenever audio devices come and go.

## Daily use

- **Double-tap Ctrl** → Glass chime, menu bar counts up `REC 0:07`.
- Talk. No time limit. (Ctrl+Option+D also toggles, as a fallback.)
- **Double-tap Ctrl** → "Transcribing…" banner. Keep focus where the text should go.
- Text pastes at your cursor with a bloop. Clipboard is restored afterward.
- Said nothing? "No speech detected" — the VAD guard prevents Whisper from
  hallucinating text on silence.

## Tuning

- Wrong vocabulary → add the term to `dictionary.txt` (one per line).
- Wrong tone / too much or too little editing → adjust `cleanup-prompt.txt`.
- Diagnosing a bad dictation → compare `last-raw.txt` (what Whisper heard)
  with `last-clean.txt` (what the LLM did to it); fix the stage that's wrong.
- Different cleanup model → `CLEANUP_MODEL` in `dictate.sh` (`ollama pull` it first).
