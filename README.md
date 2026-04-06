# Ambient Health System

## Overview

Ambient Health System is a SwiftUI iPhone prototype that interprets Apple Health patterns into ambient mood-like states and maps those states to:

* an on-screen animated ambient entity
* a connected ambient light via Raspberry Pi bridge

The project is intentionally designed as a calm, glanceable experience (not a clinical dashboard).  
It combines baseline-relative analysis, explainable interpretation surfaces, and ambient visual output.

## End-of-Semester Prototype Readiness

As implemented now, this is a strong end-of-semester prototype because it has:

* a clear core interaction loop (`Health data -> inferred state -> visual/physical ambient feedback`)
* a complete multi-screen product flow (`Now`, `Explanation`, `Trends`, `Settings`)
* non-trivial technical depth (HealthKit queries, baseline modeling, state classifier, hardware bridge)
* user-facing accessibility controls and preview/testing tooling

It is still a prototype (not production health software), but it is robust enough for a final academic demo.

## Current Implementation

### Health-state engine

The app uses Apple Health data and computes state from personal context, not raw one-off thresholds.

Current behavior includes:

* personal baseline modeling over recent weeks
* live snapshot + trend report interpretation
* workout-aware suppression to avoid false stress reads during/after exercise
* sensitivity tuning (`Gentle`, `Recommended`, `Responsive`, `Custom`)
* preview mode isolated from live classification
* developer-only demo datasets for deterministic presentation testing

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

* unique color mapping
* distinct motion/character mapping in the reference entity
* target brightness for Pi light output

### Reference entity design

The reference object is currently implemented as a living entity form (not a chart or static icon), with:

* layered organic lobes
* dynamic core behavior
* subtle state-specific character differences
* reduced-intensity behavior when accessibility reduction is enabled

### UI surfaces

* `Now`
  * live state title + short interpretation line
  * ambient entity
  * state-aware calendar memory
  * Pi connection indicator
* `Explanation`
  * `What This May Mean` (plain-language interpretation)
  * `Pattern Insight` (non-duplicate pattern-level interpretation)
  * preview-aware explanation behavior
* `Trends`
  * weekly trend cards for recovery, resting rhythm, movement, sleep duration, and sleep quality
  * calmer-mode simplified trend presentation
* `Settings`
  * sensitivity controls
  * state preview controls
  * HealthKit status breakdown
  * `Last refresh` + `Last successful Health read` timestamps
  * ambient object send log (status + latency)
  * per-state ambient brightness overrides for Pi output
  * accessibility controls
  * dev-only classifier debug snapshot + confidence readout

### Accessibility features

Current accessibility options include:

* `Calmer Mode`
* `Reduce Motion`
* `Larger Text`
* `Higher Contrast`

These options are presentation-layer adjustments only and do not alter classification logic.

### Preview mode

State preview currently supports:

* previewing any state in UI
* temporary Pi send for previewed state
* returning to live state routing after preview ends

### Developer testing surfaces

Debug builds include:

* `Debug Snapshot (Dev Only)` with a detailed classifier reasoning report
* one-line classifier confidence summary for faster diagnosis
* `Demo Mode (Dev Only)` with selectable deterministic datasets for each health state

## Repository Structure

### iOS app

* `Ambient Health Interface/`
  * `App/`
  * `Controllers/`
  * `DetailViews/`
  * `HealthStore/`
  * `Models/`
  * `NowUI/`
  * `Reference/`
  * `Support/`

### Xcode project

* `Ambient Health Interface.xcodeproj/`

### Pi backend

* `Ambient-Health-PI/` (FastAPI bridge for smart-bulb control)
  * supports `POST /set_light`, `OPTIONS /set_light`, `GET /health`, `POST /turn_on`, and `POST /turn_off`
  * includes warm-device reuse, fallback rediscovery, duplicate skipping, and latest-only request collapsing

## iOS Setup

1. Open [Ambient Health Interface.xcodeproj](/Users/nathanmcmillan/Desktop/XCodeFiles/Ambient%20Health%20Interface/Ambient%20Health%20Interface.xcodeproj) in Xcode.
2. Run on a physical iPhone for real HealthKit behavior.
3. Grant Health permissions when prompted.
4. Ensure the iPhone can reach the Pi bridge URL on the same network.

## Pi Backend Setup

From project root:

```bash
cd Ambient-Health-PI
make install
cp .env.example .env
```

Set required values in `.env`:

```env
USERNAME=your_email
PASSWORD=your_password
BULB_IP=your_bulb_ip
```

Run:

```bash
make run
```

Default server:

```text
http://0.0.0.0:8000
```

Set iOS bridge URL with environment `PI_BASE_URL` if needed.

## Usage Flow

1. Start Pi backend.
2. Launch iPhone app.
3. Connect Health and refresh.
4. App computes live state from current signals + baseline context.
5. App updates on-screen ambient entity and sends mapped state/brightness to Pi bridge.
6. Use `State Preview` in Settings to test state-specific behavior.

## Notes and Limitations

* Wellness-oriented interpretation only (not diagnostic or medical advice).
* Signal quality depends on Apple Health data availability and recency.
* Smart bulb still requires its own network onboarding outside the app.
* Current hardware path is single-bridge / single-light oriented.
