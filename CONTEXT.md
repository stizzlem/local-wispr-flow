# Context — Local Wispr Flow Replacement

Background and decision log for this project. `BUILD-PROMPT.md` is the thing to paste into Fable 5; this file is the "why" behind it.

## The goal
Recreate Wispr Flow's core behavior locally on the Mac: hotkey → speak → polished text appears at cursor. Free, offline, no subscription (Wispr Flow is ~$15/mo).

## How Wispr Flow actually works
A two-stage cloud pipeline triggered by a hotkey (Fn on Mac):
1. **Speech → raw text** via an ASR model (Whisper-class), on Wispr's servers.
2. **Raw text → polished text** via an LLM layer: removes filler words, fixes punctuation, resolves self-corrections, adapts tone to the app.
3. Injects finished text at the cursor in any app.

Key insight: the "magic" is the second (LLM cleanup) stage, not just transcription. Apple's built-in dictation feels bad because it has NO cleanup stage and uses a weaker model. Our build fixes both.

## Why local + free works
- **whisper.cpp** — audio → raw text. Free, open source, Metal-accelerated on Apple Silicon.
- **Ollama** + a model — the cleanup/formatting LLM. Free, open source, runs models locally with no account or per-use cost.
- Glue (hotkey + cursor injection) — the only custom code.
Total cost: $0/month. Only cost is disk (a few GB) + RAM while running.

## Hardware (verified 2026-07-02)
- Apple M2 Pro, 32 GB RAM, macOS 26.5.1, arm64, ~83 GB free.
- Over-provisioned. Can run `large-v3-turbo` (best-accuracy Whisper) in real time AND an 8–9B cleanup model simultaneously. No need to trade accuracy for latency.

## Architecture (final — 3 stages, no VAD)
```
[Press combo to START] + speak + [press combo to STOP]
      ↓
Mic audio (16 kHz)   ← recording between toggles
      ↓
whisper.cpp (large-v3-turbo, Metal) → raw transcript   ← on key release
      ↓
Ollama cleanup (llama3.1 / gemma2:9b) → polished text
      ↓
Injected at cursor (any app)
```

## Decision log
- **whisper.cpp over faster-whisper.** A second Opus draft recommended faster-whisper (CTranslate2, ~2.3–4x faster, bundled Silero VAD). Its main advantage is the bundled VAD. We use **hold-to-talk**, so the user defines turn boundaries and VAD is unnecessary — which removes faster-whisper's edge. whisper.cpp wins on simplicity (standalone binary, no Python env for STT).
- **Manual toggle over hands-free/VAD.** User marks start/stop themselves, so no VAD needed — no false triggers, can't cut you off mid-sentence. Eliminates the VAD stage entirely.
- **Toggle-combo, not single-key hold.** User is on an external keyboard: left Option only, no Fn, no right Option. Single-key hold-to-talk isn't viable (left Option is needed for normal typing). Chose a press-to-start / press-to-stop combo (Ctrl+Option+D preferred, Ctrl+Space fallback) that works on any keyboard. This is still manual turn-marking, so the no-VAD decision stands.
- **large-v3-turbo from the start.** Hardware allows it; no reason to start with tiny/base (that advice is for RAM-constrained machines).
- **Build core from scratch, use helper for OS glue.** User wants to learn and control the cleanup prompt, so the Whisper→Ollama core is hand-written (~40 lines, educational, tunable). Mic/hotkey/cursor-injection use a proven helper — that's macOS Accessibility plumbing that teaches nothing and just creates bugs.
- **Do NOT fork an existing clone.** local-whisper / OpenWhispr exist and work, but user chose a from-scratch build for learning + control.

## Why this beats the Mac's built-in dictation (the user's real concern)
| Built-in dictation fails because | This fixes it by |
|---|---|
| Weak/small on-device model | large-v3-turbo (Whisper-class, full size) |
| No cleanup layer (raw words, no punctuation) | Ollama cleanup stage (the Wispr "magic") |
| Times out / cuts you off | Hold-to-talk — you control the boundaries |
| Chokes on domain vocabulary | Custom dictionary (Phase 3): MasterControl, CFR Part 11, IdP, QMS, SSO |
| Cloud-dependent / inconsistent | 100% local, deterministic |

## Expectations / honest caveats
- STT is **batch, not streaming** — text lands after you release the key (~half-second pause), not live word-by-word. Normal; Wispr feels similar.
- Won't be perfect — no STT is — but should be a large step up from built-in dictation and in the same league as Wispr. Unlike a black box, every stage is tunable (model size, cleanup prompt, dictionary).

## Phases
1. **Prove the engines** — install Ollama + whisper.cpp, pull models, transcribe a deliberately-messy 20s test, show raw vs. cleaned side by side. (Gate: user satisfied with accuracy.)
2. **Full experience** — hotkey capture + cursor injection, hold-to-talk, test in Slack/Notes/VS Code.
3. **Tune** — cleanup prompt (formality, filler handling), custom dictionary for domain terms, final model A/B (small vs large-v3-turbo; 3B vs 8–9B cleanup).

## Sources
- Wispr Flow: https://wisprflow.ai/ , https://wisprflow.ai/features
- local-whisper: https://github.com/luisalima/local-whisper
- OpenWhispr: https://github.com/openwhispr/openwhispr , https://openwhispr.com/
- Whisper model sizes: https://openwhispr.com/blog/whisper-model-sizes-explained
- whisper.cpp on Apple Silicon: https://getspeakup.app/blog/whisper-cpp-benchmark-mac/
