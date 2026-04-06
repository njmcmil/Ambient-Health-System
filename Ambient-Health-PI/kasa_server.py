from __future__ import annotations

import asyncio
from typing import Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from app import health_status, set_state, turn_off, turn_on

# uvicorn kasa_server:app --host 0.0.0.0 --port 8000

app = FastAPI(title="Ambient Health Kasa Bridge")


class LightRequest(BaseModel):
    color: str = Field(..., min_length=1)
    brightness: int = Field(..., ge=0, le=100)


COLOR_MAP = {
    "red": (0, 100),
    "orange": (30, 100),
    "yellow": (60, 100),
    "green": (120, 100),
    "blue": (240, 100),
    "purple": (270, 100),
    "gray": (0, 0),
}

_REQUEST_LOCK = asyncio.Lock()
_LATEST_REQUEST: dict[str, Any] | None = None
_IS_PROCESSING = False


def resolve_color(color: str) -> tuple[str, int, int]:
    normalized = color.strip().lower()
    if normalized not in COLOR_MAP:
        valid = ", ".join(sorted(COLOR_MAP.keys()))
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported color '{color}'. Expected one of: {valid}",
        )
    hue, saturation = COLOR_MAP[normalized]
    return normalized, hue, saturation


async def drain_latest_request() -> dict[str, Any] | None:
    global _LATEST_REQUEST

    async with _REQUEST_LOCK:
        if _LATEST_REQUEST is None:
            return None
        request = _LATEST_REQUEST
        _LATEST_REQUEST = None
        return request


async def enqueue_light_request(color: str, brightness: int) -> None:
    global _IS_PROCESSING, _LATEST_REQUEST

    async with _REQUEST_LOCK:
        _LATEST_REQUEST = {"color": color, "brightness": brightness}
        if _IS_PROCESSING:
            return
        _IS_PROCESSING = True

    try:
        while True:
            next_request = await drain_latest_request()
            if next_request is None:
                break

            _, hue, saturation = resolve_color(next_request["color"])
            await set_state(hue, saturation, next_request["brightness"])
    finally:
        async with _REQUEST_LOCK:
            _IS_PROCESSING = False


@app.options("/set_light")
async def set_light_options():
    return {"status": "ok", "route": "/set_light"}


@app.get("/health")
async def health():
    try:
        return await health_status()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Bridge unhealthy: {exc}") from exc


@app.post("/set_light")
async def set_light(request: LightRequest):
    normalized_color, _, _ = resolve_color(request.color)
    brightness = max(0, min(100, int(request.brightness)))

    try:
        await enqueue_light_request(normalized_color, brightness)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to update bulb: {exc}") from exc

    return {
        "status": "ok",
        "color": normalized_color,
        "brightness": brightness,
    }


@app.post("/set_color")
async def set_color_alias(request: LightRequest):
    return await set_light(request)


@app.post("/turn_off")
async def bulb_off():
    try:
        await turn_off()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to turn bulb off: {exc}") from exc
    return {"status": "off"}


@app.post("/turn_on")
async def bulb_on():
    try:
        await turn_on()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to turn bulb on: {exc}") from exc
    return {"status": "on"}
