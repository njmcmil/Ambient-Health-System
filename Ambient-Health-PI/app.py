# app.py
from kasa.discover import Discover
import asyncio
import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

USERNAME = os.getenv("USERNAME")
PASSWORD = os.getenv("PASSWORD")
BULB_IP = os.getenv("BULB_IP")




async def set_color(hue, saturation=100, brightness=100):
    device = await Discover.discover_single(BULB_IP, username=USERNAME, password=PASSWORD)
    await device.update()
    await device.turn_on()
    await device.set_brightness(brightness)
    await device.set_hsv(hue, saturation, brightness)
    print(f"Color set to HSV({hue}, {saturation}, {brightness})")




async def turn_off():
    device = await Discover.discover_single(BULB_IP, username=USERNAME, password=PASSWORD)
    await device.update()
    await device.turn_off()
    print("Turned off")


