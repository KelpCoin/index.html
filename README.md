# BrownEye Cortex Voice Bus

This module gives you a **phone-to-desktop live idea relay**:

- Phone captures voice.
- Speech is converted to text using either:
  - **Browser STT** (fastest realtime loop), or
  - **Whisper** via `faster-whisper` on your desktop server.
- Transcript events are pushed over a WebSocket "bus" to all desktop listeners in the same room.

## Quick start

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn cortex_bus_server:app --host 0.0.0.0 --port 8000
```

Then:

1. Open `http://<desktop-ip>:8000` on your **phone**.
2. Open the same URL on your **desktop**.
3. Set both to the same Room ID (default `brown-eye-main`).
4. On phone: choose role `Phone`, connect, then start capture.
5. On desktop: choose role `Desktop`, connect, and monitor transcript.

## Notes

- Whisper mode uses 4-second audio chunks for near-real-time transcription.
- Browser STT mode depends on browser support (best on Chrome-based mobile browsers).
- For true private/offline STT, you can keep using Whisper mode with a local model.

## Optional: Vosk swap

If you prefer Vosk, replace the `/api/transcribe` handler internals with a Vosk recognizer pipeline that ingests PCM chunks. The WebSocket bus and front-end flow can remain unchanged.
