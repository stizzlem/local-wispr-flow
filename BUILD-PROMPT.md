# Fable 5 Build Prompt — Local Wispr Flow Replacement

Paste everything below the line into Fable 5 to start the build.
Full research/decision context is in `CONTEXT.md` in this same folder — read it if you need the "why" behind any decision.

---

Build me a free, fully-local speech-to-text dictation tool on my Mac, from scratch, that replaces Wispr Flow. Work with me step by step and explain new concepts as we go — I'm newer to local AI tooling and want to actually understand what we're building.

## My hardware (already verified — don't downgrade for latency)
- Apple M2 Pro, 32 GB RAM, macOS 26.5.1, arm64, ~83 GB free disk.
- I'm over-provisioned for this. Use the best-accuracy models, not the small ones.

## What it must do (3-stage pipeline, toggle trigger — NO VAD)
Trigger is a KEYBOARD-COMBO TOGGLE: I press a combo once to START recording, press it again to STOP. NOT hold-to-talk. Reason: I'm on an external keyboard with only a left Option key and no Fn, so single-key hold-to-talk won't work. Because I still mark the start/stop manually, we still do NOT need Silero VAD / silence detection. Keep it to three stages:

- Preferred combo: **Ctrl+Option+D** (fallback Ctrl+Space if that conflicts). Verify it doesn't collide with an existing macOS/app shortcut before finalizing, and tell me what you picked. Must work on an external keyboard.

1. **Capture** mic audio at 16 kHz between the start-toggle and stop-toggle.
2. **Transcribe** with whisper.cpp using the `large-v3-turbo` model, Metal-accelerated → raw transcript.
3. **Clean up** the raw transcript with a local Ollama LLM (test both `llama3.1` and `gemma2:9b`) → polished text. The cleanup removes "um/uh/like," fixes punctuation, and resolves mid-sentence self-corrections (e.g. "Tuesday, no Wednesday" → "Wednesday").
4. **Inject** the polished text at my cursor in whatever app is focused.

## Build philosophy — this is a FROM-SCRATCH build, and it's deliberate
- I want to WRITE THE CORE MYSELF (with your guidance): the Whisper → Ollama cleanup pipeline. This is the educational, tunable heart of the tool. I want the cleanup LLM prompt in a plain file I can edit in seconds — that prompt is the soul of the tool and I want full control of it.
- For the annoying macOS OS-glue (global hotkey registration, cursor text injection via Accessibility APIs), use a small proven helper library rather than hand-rolling low-level APIs — that plumbing teaches me nothing and just creates bugs. Explain what you chose and why.
- Do NOT install or fork an existing Wispr clone (local-whisper, OpenWhispr, etc.). We are building our own.

## Backend decision (already made — don't re-litigate)
- Use **whisper.cpp**, NOT faster-whisper. Reason: faster-whisper's main edge is bundled Silero VAD, which I don't need with a manual toggle trigger. whisper.cpp = fewer moving parts, no Python env to babysit for the STT stage, Metal-accelerated on my Mac.

## Hard constraints
- 100% local and free. $0/month, no cloud calls, no subscription, no account.
- Everything runs offline once installed.

## Do Phase 1 FIRST — prove it before we build the full app
Before wiring up the hotkey and cursor injection, get the core pipeline working and run ONE test:
1. Install Ollama + whisper.cpp, pull `large-v3-turbo` and a cleanup model.
2. Have me record ~20 seconds of deliberately messy speech: some "ums," one self-correction ("Tuesday, no Wednesday"), and a technical term ("MasterControl" or "CFR Part 11").
3. Show me the RAW whisper output AND the cleaned-up version side by side so I can judge accuracy.

Only after I'm satisfied with Phase 1 do we build the hotkey + cursor-injection layer (Phase 2) and then tune (Phase 3: cleanup prompt, custom dictionary for my domain terms).

## Working style
- Ask me before installing anything, and tell me what each command does.
- Explain new concepts (Ollama, whisper.cpp, Metal acceleration, Accessibility APIs) briefly as they come up.
- Keep responses concise and action-oriented. No emojis.
- Put all project files in this folder: `~/Fable5-Projects/local-wispr-flow/`

The plan is already decided — don't confirm it back or restate it. Go straight to Phase 1: tell me the exact commands to install Ollama + whisper.cpp and pull the models, what each does, and wait for my okay before running anything.
