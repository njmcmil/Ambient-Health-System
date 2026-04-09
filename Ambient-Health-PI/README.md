# Ambient Health Pi Bridge

## Overview

This folder contains the Raspberry Pi backend used by the Ambient Health iPhone app to control a TP-Link Kasa smart bulb.

The bridge is a small FastAPI service that:

* accepts color + brightness requests from the iPhone app
* translates those requests into Kasa bulb updates
* keeps a warm device connection when possible for better responsiveness
* exposes a health route for quick testing

It is intentionally small and built around the app's current contract, not a larger device-control platform.

## Files

* `kasa_server.py`
  * FastAPI routes used by the app
* `app.py`
  * Kasa discovery, reconnect, and bulb update helpers
* `requirements.txt`
  * Python dependencies
* `makefile`
  * helper commands for install / run

## Environment

Create a `.env` file in this folder with:

```env
USERNAME=your_kasa_username
PASSWORD=your_kasa_password
BULB_IP=your_bulb_ip
```

## Recommended Pi Setup

On newer Raspberry Pi OS images, global `pip install` often fails because Python is externally managed.

The most reliable setup is:

```bash
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

Then run the server with the virtual environment active.

## Run

With the virtual environment active:

```bash
python -m dotenv run -- uvicorn kasa_server:app --host 0.0.0.0 --port 8000
```

If you want to use the helper target instead:

```bash
make run
```

Default server:

```text
http://0.0.0.0:8000
```

## Routes

### `OPTIONS /set_light`

Used by the iPhone app to confirm the route is reachable without changing the bulb.

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

* `red`
* `orange`
* `yellow`
* `green`
* `blue`
* `purple`
* `gray`

### `POST /set_color`

Backward-compatible alias for older clients.

### `POST /turn_on`

Turns the bulb on.

### `POST /turn_off`

Turns the bulb off.

### `GET /health`

Bridge health check. This is the fastest way to confirm:

* FastAPI is running
* the Pi route is reachable
* the Pi can still talk to the bulb

## Quick Tests

Health check on the Pi:

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

The current bridge keeps the same general structure, but adds a few practical improvements:

* warm Kasa-device reuse when possible
* fallback rediscovery if that cached device goes stale
* serialized bulb access so rapid requests do not fight each other
* latest-only request collapsing for fast slider updates
* duplicate state skipping when the same HSV state is already applied

These changes are meant to improve responsiveness without changing the app's API contract.

## Systemd Option

If you want the Pi service to survive terminal closes and restart on boot, run it as a `systemd` service.

Typical service flow:

1. point `ExecStart` at your venv Python
2. set `WorkingDirectory` to this folder
3. load `.env`
4. enable the service

Useful checks after that:

```bash
sudo systemctl status ambient-health-pi.service
journalctl -u ambient-health-pi.service -f
```

## Notes

* The bulb must be reachable from the Pi on the same usable local network.
* A successful ping alone is not enough; Kasa auth still has to succeed.
* If the Kasa credentials or bulb IP are wrong, `/health` and `/set_light` can fail even though FastAPI itself is working.
