# Ambient Health System

## Overview

Ambient Health System is a SwiftUI iPhone app that turns Apple Health patterns into mood-like ambient states and sends those states to a smart light through a Raspberry Pi backend.

The app is designed to feel calm and glanceable rather than dashboard-heavy. Instead of pushing raw metrics to the foreground, it:

* builds a personal multi-week baseline from Apple Health
* compares the current day to that baseline
* classifies the result into ambient states such as `Restored`, `Grounded`, `Neutral`, `Low Energy`, `Stressed`, `Drained`, and `Overloaded`
* visualizes the state through an animated reference object and a connected light

The current system includes:

* iOS frontend in SwiftUI
* Apple Health / HealthKit integration
* baseline-relative mood-state classification
* a Raspberry Pi FastAPI bridge for ambient light output
* TP-Link smart bulb control through the Pi backend

## Current Features

### Health state engine

The app no longer uses only simple fixed thresholds. It now:

* builds a personal baseline over recent weeks
* interprets the current day relative to that baseline
* uses workout-aware stress suppression so exercise is less likely to be mistaken for emotional stress
* treats preview mode separately from live state classification

### Ambient states

The current state set is:

* `Restored`
* `Grounded`
* `Neutral`
* `Low Energy`
* `Stressed`
* `Drained`
* `Overloaded`

Each state has:

* its own color
* its own reference-object motion and shape language
* its own ambient bulb brightness target

### UI surfaces

The app currently includes:

* `Now`
  * animated ambient reference object
  * weekly calendar / state memory
  * live connection indicator for the ambient object
* `Explanation`
  * state explanation
  * pattern insight
  * preview-aware interpretation
* `Trends`
  * weekly summaries
  * calmer-mode text-only trend presentation
  * preview-aware trend interpretation
* `Settings`
  * sensitivity controls
  * calmer mode / accessibility option
  * state preview mode
  * HealthKit status

### Preview mode

State preview mode can:

* preview a chosen health state in the app UI
* temporarily send that preview state to the ambient object
* restore the real live state after returning to live mode

### Calmer mode

Calmer mode is an accessibility-oriented presentation mode for anxious users. It:

* softens motion and glow
* disables press interaction on the reference object
* reduces visual intensity in the UI
* changes explanation / trends wording to be less clinical and less intense

It does not change the underlying health-state logic.

## Repository Structure

* `Ambient Health Interface/`
  SwiftUI iOS application source

* `Ambient Health Interface.xcodeproj/`
  Xcode project

* `Ambient-Health-PI/`
  Raspberry Pi FastAPI backend used to drive the smart bulb

## Frontend Setup

1. Open [Ambient Health Interface.xcodeproj](/Users/nathanmcmillan/Desktop/XCodeFiles/Ambient%20Health%20Interface/Ambient%20Health%20Interface.xcodeproj) in Xcode.
2. Run on a physical iPhone for real HealthKit behavior.
3. Grant Apple Health permissions when prompted.
4. Make sure the phone can reach the Pi over the same local network.

## Backend Setup

From the project root:

```bash
cd Ambient-Health-PI
```

Install dependencies:

```bash
make install
```

Create the environment file:

```bash
cp .env.example .env
```

Fill in the required values in `.env`:

```env
USERNAME=your_email
PASSWORD=your_password
BULB_IP=your_bulb_ip
```

Run the backend:

```bash
make run
```

The server runs on:

```text
http://0.0.0.0:8000
```

The iOS app sends HTTP POST requests to this backend, which then updates the smart bulb.

## Usage

1. Start the Pi backend.
2. Launch the iPhone app.
3. Let the app read current Apple Health data.
4. The app classifies the current state and sends the matching ambient state to the Pi.
5. Use `State Preview` in Settings if you want to test how a given state looks in both the UI and the ambient object.

## Notes

* This system is now driven by live Apple Health data rather than only simulated states.
* The app uses HealthKit data such as sleep, HRV, resting heart rate, respiratory rate, movement, exercise, and mindfulness when available.
* The Pi connection indicator in the `Now` screen reflects the real request status from the app's last send attempt.
* Devices still need to be on a reachable local network for live ambient light control.
* `.env` is not included for security.

## Limitations

* Single ambient light path today
* Current bulb flow still depends on a separate smart-bulb setup outside the app
* Mood inference is wellness-oriented, not clinical or diagnostic
* Real-world behavior still depends on Apple Health signal availability and quality

## Future Work

* better hardware onboarding / provisioning
* richer ambient-object hardware output beyond a single bulb
* broader smart-light support
* better persistence / diagnostics for the Pi bridge
* more explainable but still calm state interpretation
