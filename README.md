# Ambient Health System

## Overview

This project is an interactive prototype that visualizes simulated health states using a SwiftUI app and a TP-Link Kasa smart bulb.

The system includes:

* iOS frontend (SwiftUI)
* Raspberry Pi backend (FastAPI, simulated)
* Smart bulb output (color changes)

The app sends HTTP POST requests to the Pi, which updates the bulb color in real time.

---

## Repository Structure

* Ambient Health Interface/
  SwiftUI iOS application

* Ambient Health Interface.xcodeproj/
  Xcode project

* Ambient-Health-PI/
  Raspberry Pi backend (FastAPI + bulb control)

---

## Backend Setup (Ambient-Health-PI)

cd Ambient-Health-PI

1. Install dependencies:
   make install

2. Create environment file:
   cp .env.example .env

3. Fill in:
   USERNAME=your_email
   PASSWORD=your_password
   BULB_IP=your_bulb_ip

4. Run server:
   make run

Server runs on:
http://0.0.0.0:8000

---

## Frontend Setup

1. Open:
   Ambient Health Interface.xcodeproj

2. Run in Xcode (simulator or iPhone)

3. Set base URL to your Pi:
   http://<your-pi-ip>:8000

---

## Usage

1. Start backend (make run)
2. Run iOS app
3. Simulate a health state
4. Bulb updates color

---

## Notes

* Backend is simulated (no database)
* Uses HTTP POST requests via URLSession
* Devices must be on same network
* .env is not included for security

---

## Limitations

* Single bulb only
* Predefined states only
* No real sensor data

---

## Future Work

* Real health data integration
* Multi-device support
* Persistent backend
