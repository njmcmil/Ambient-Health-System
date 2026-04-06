# Ambient Health Pi Bridge

## Overview

This folder contains the Raspberry Pi backend used by the Ambient Health iPhone app to control a TP-Link Kasa smart bulb.

The backend is a small FastAPI bridge that:
- accepts color + brightness commands from the iPhone app
- translates those commands into Kasa bulb updates
- keeps a warm device connection when possible for better responsiveness
- exposes a lightweight health route for testing

## Files

- `kasa_server.py`
  FastAPI routes used by the app
- `app.py`
  Kasa device discovery and bulb control helpers
- `requirements.txt`
  Python dependencies
- `makefile`
  install/run helpers

## Environment

Create a `.env` file in this folder with:

```env
USERNAME=your_kasa_username
PASSWORD=your_kasa_password
BULB_IP=your_bulb_ip
```

## Install

```bash
make install
```

## Run

```bash
make run
```

Server default:

```text
http://0.0.0.0:8000
```

## Routes

### `OPTIONS /set_light`

Used by the iPhone app to check whether the bridge route is reachable.

### `POST /set_light`

Primary route used by the current app.

Request body:

```json
{
  "color": "purple",
  "brightness": 15
}
```

Supported colors:
- `red`
- `orange`
- `yellow`
- `green`
- `blue`
- `purple`
- `gray`

### `POST /set_color`

Backward-compatible alias for older clients.

### `POST /turn_on`

Turns the bulb on.

### `POST /turn_off`

Turns the bulb off.

### `GET /health`

Simple backend health check.

## Quick Tests

Health check:

```bash
curl http://127.0.0.1:8000/health
```

Probe route:

```bash
curl -X OPTIONS http://127.0.0.1:8000/set_light
```

Send a state:

```bash
curl -X POST http://127.0.0.1:8000/set_light \
  -H "Content-Type: application/json" \
  -d '{"color":"purple","brightness":15}'
```

Turn bulb on/off:

```bash
curl -X POST http://127.0.0.1:8000/turn_on
curl -X POST http://127.0.0.1:8000/turn_off
```

## Reliability Notes

The current backend keeps the same overall control structure, but adds a few practical improvements:
- warm Kasa device reuse when possible
- fallback rediscovery if that cached device goes stale
- serialized bulb access so rapid requests do not fight each other
- latest-only request collapsing for fast slider updates
- duplicate state skipping when the same HSV state is already applied

These changes are meant to improve responsiveness without changing the app's contract.
