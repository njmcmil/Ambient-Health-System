# kasa_server.py
from fastapi import FastAPI
from pydantic import BaseModel
from app import set_color
import asyncio
#uvicorn kasa_server:app --host 0.0.0.0 --port 8000

app = FastAPI()

# Pydantic model for JSON body
class ColorRequest(BaseModel):
    color: str

@app.post("/set_color")
async def change_color(request: ColorRequest):
    # Map your colors to HSV hue values, change last value for brightness
    color_map = {
        "red": (0, 100, 10),
        "orange": (30, 100, 10),
        "yellow": (60, 100, 10),
        "green": (120, 100, 10),
        "blue": (240, 100, 10),
        "purple": (270, 100, 10),
        "gray": (0, 0, 10)  # gray: zero saturation, medium brightness
    }

    hue, sat, bri = color_map.get(request.color.lower(), (0, 100, 10))
    await set_color(hue, sat, bri)
    return {"status": "ok", "color": request.color}


