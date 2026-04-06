from __future__ import annotations

import asyncio
import os
from typing import Any

from dotenv import load_dotenv
from kasa.discover import Discover

load_dotenv()

USERNAME = os.getenv("USERNAME")
PASSWORD = os.getenv("PASSWORD")
BULB_IP = os.getenv("BULB_IP")

_DEVICE_LOCK = asyncio.Lock()
_CACHED_DEVICE: Any | None = None
_LAST_APPLIED_STATE: tuple[int, int, int] | None = None


def require_config() -> tuple[str, str, str]:
    missing = [
        name
        for name, value in {
            "USERNAME": USERNAME,
            "PASSWORD": PASSWORD,
            "BULB_IP": BULB_IP,
        }.items()
        if not value
    ]
    if missing:
        missing_text = ", ".join(missing)
        raise RuntimeError(f"Missing required environment variables: {missing_text}")
    return USERNAME, PASSWORD, BULB_IP


async def discover_device() -> Any:
    username, password, bulb_ip = require_config()
    device = await Discover.discover_single(
        bulb_ip,
        username=username,
        password=password,
    )
    await device.update()
    return device


async def get_device(force_refresh: bool = False) -> Any:
    global _CACHED_DEVICE

    if _CACHED_DEVICE is None or force_refresh:
        _CACHED_DEVICE = await discover_device()
        return _CACHED_DEVICE

    try:
        await _CACHED_DEVICE.update()
        return _CACHED_DEVICE
    except Exception:
        _CACHED_DEVICE = await discover_device()
        return _CACHED_DEVICE


async def apply_hsv(device: Any, hue: int, saturation: int, brightness: int) -> None:
    await device.turn_on()
    await device.set_hsv(hue, saturation, brightness)


async def set_state(hue: int, saturation: int, brightness: int) -> None:
    global _LAST_APPLIED_STATE

    hue = max(0, min(360, int(hue)))
    saturation = max(0, min(100, int(saturation)))
    brightness = max(0, min(100, int(brightness)))
    requested_state = (hue, saturation, brightness)

    async with _DEVICE_LOCK:
        if _LAST_APPLIED_STATE == requested_state:
            print(f"Skipping duplicate HSV{requested_state}")
            return

        device = await get_device(force_refresh=False)

        try:
            await apply_hsv(device, hue, saturation, brightness)
        except Exception:
            device = await get_device(force_refresh=True)
            await apply_hsv(device, hue, saturation, brightness)

        _LAST_APPLIED_STATE = requested_state
        print(f"Applied HSV({hue}, {saturation}, {brightness})")


async def turn_on() -> None:
    async with _DEVICE_LOCK:
        device = await get_device(force_refresh=False)
        try:
            await device.turn_on()
        except Exception:
            device = await get_device(force_refresh=True)
            await device.turn_on()
        print("Bulb turned on")


async def turn_off() -> None:
    async with _DEVICE_LOCK:
        device = await get_device(force_refresh=False)
        try:
            await device.turn_off()
        except Exception:
            device = await get_device(force_refresh=True)
            await device.turn_off()
        print("Bulb turned off")


async def health_status() -> dict[str, str]:
    async with _DEVICE_LOCK:
        await get_device(force_refresh=False)
    return {"status": "ok", "device": "reachable"}
