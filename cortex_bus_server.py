"""BrownEye Cortex voice bus server.

Run:
  uvicorn cortex_bus_server:app --host 0.0.0.0 --port 8000
"""

from __future__ import annotations

import tempfile
from collections import defaultdict
from pathlib import Path

from fastapi import FastAPI, File, Form, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles


class ConnectionHub:
    """Simple room-based WebSocket fanout."""

    def __init__(self) -> None:
        self.rooms: dict[str, set[WebSocket]] = defaultdict(set)

    async def connect(self, room: str, ws: WebSocket) -> None:
        await ws.accept()
        self.rooms[room].add(ws)

    def disconnect(self, room: str, ws: WebSocket) -> None:
        if room not in self.rooms:
            return
        self.rooms[room].discard(ws)
        if not self.rooms[room]:
            del self.rooms[room]

    async def broadcast(self, room: str, event: dict) -> None:
        stale_connections: list[WebSocket] = []
        for ws in self.rooms.get(room, set()):
            try:
                await ws.send_json(event)
            except Exception:
                stale_connections.append(ws)

        for ws in stale_connections:
            self.disconnect(room, ws)


hub = ConnectionHub()
app = FastAPI(title="BrownEye Cortex Voice Bus")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

BASE_DIR = Path(__file__).resolve().parent
app.mount("/static", StaticFiles(directory=BASE_DIR), name="static")

# Whisper is optional at import-time, to keep startup light.
_whisper_model = None


def get_whisper_model():
    """Lazy-load faster-whisper model on first use."""
    global _whisper_model
    if _whisper_model is None:
        from faster_whisper import WhisperModel

        _whisper_model = WhisperModel("small", compute_type="int8")
    return _whisper_model


@app.get("/")
async def root() -> FileResponse:
    return FileResponse(BASE_DIR / "index.html")


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, room: str = "brown-eye-main") -> None:
    await hub.connect(room, websocket)

    try:
        while True:
            payload = await websocket.receive_json()
            event_type = payload.get("type")
            if event_type == "transcript":
                text = (payload.get("text") or "").strip()
                if text:
                    await hub.broadcast(
                        room,
                        {
                            "type": "transcript",
                            "text": text,
                            "source": payload.get("source", "unknown"),
                        },
                    )
    except WebSocketDisconnect:
        hub.disconnect(room, websocket)


@app.post("/api/transcribe")
async def transcribe_chunk(
    audio: UploadFile = File(...),
    room: str = Form("brown-eye-main"),
) -> dict:
    suffix = Path(audio.filename).suffix or ".webm"

    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(await audio.read())
        tmp_path = Path(tmp.name)

    model = get_whisper_model()
    segments, _info = model.transcribe(str(tmp_path), vad_filter=True, language="en")

    transcript = " ".join(segment.text.strip() for segment in segments).strip()
    if transcript:
        await hub.broadcast(room, {"type": "transcript", "text": transcript, "source": "whisper"})

    try:
        tmp_path.unlink(missing_ok=True)
    except Exception:
        pass

    return {"ok": True, "text": transcript}
