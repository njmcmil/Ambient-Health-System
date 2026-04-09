# Ambient Health System

## Overview

Ambient Health System is a SwiftUI iPhone prototype that interprets Apple Health patterns into ambient, mood-like health states and maps those states to:

* an animated on-screen ambient entity
* a connected ambient light through a Raspberry Pi bridge

The experience is intentionally built as a calm wellness interface, not a clinical dashboard.  
It uses Apple Health trends, personal baseline context, and lightweight explanation surfaces to turn health data into something more readable and emotionally legible.

## Wellness Framing

Ambient Health is a wellness interpretation layer built on top of Apple Health data.

It is designed to:

* help users notice recovery, strain, and energy patterns
* surface plain-language context around those patterns
* make health data feel glanceable and ambient

It is **not** intended to diagnose, treat, or provide medical advice.

## Core Product Loop

The app is built around this flow:

1. Read current and recent Apple Health signals.
2. Compare those signals against the user's personal baseline.
3. Translate that context into a current health state.
4. Show that state through the animated entity, explanation, trends, and calendar memory.
5. Optionally send the mapped color + brightness state to the Raspberry Pi light bridge.

## Current Health-State Logic

### State set

The app currently uses these ambient states:

* `Restored`
* `Grounded`
* `Neutral`
* `Low Energy`
* `Stressed`
* `Drained`
* `Overloaded`

Each state has:

* a color identity
* a motion / character treatment in the ambient entity
* a matching brightness target for the Pi light
* a short Now-screen interpretation line

### Signals used

The app can use these Apple Health signals when available:

* sleep duration
* sleep-stage quality context
* overnight breathing rate
* oxygen saturation
* sleeping wrist temperature
* current heart rate
* resting heart rate
* heart rate variability (HRV)
* step count
* exercise minutes
* active energy
* distance walking / running
* flights climbed
* mindful minutes
* recent workout context

### Baseline-relative interpretation

The app does **not** rely on one-size-fits-all thresholds alone.

Current classification behavior includes:

* personal baseline modeling over recent weeks
* live snapshot interpretation for the current day
* weekly trend context
* workout-aware suppression to avoid false stress reads during or shortly after exercise
* adjustable sensitivity (`Gentle`, `Recommended`, `Responsive`, `Custom`)

### Overnight signal ownership

Overnight recovery signals are assigned to the **wake-up day**.

That means:

* sleep from Tuesday night into Wednesday morning belongs to **Wednesday**
* breathing overnight from that same sleep session also belongs to **Wednesday**
* sleep quality, oxygen, and sleeping wrist temperature from that session also belong to **Wednesday**

This same wake-up-day logic is used across:

* current live state interpretation
* explanation surfaces
* weekly trends
* calendar history
* tap-on-day calendar details

### Current day vs past days

The app treats the current day and previous days differently on purpose:

* **Current day**
  * uses the newest available data
  * adapts to the user's current baseline
  * stays gray / no-data if there is not enough meaningful signal yet
* **Past days**
  * preserve the state history already captured for that day
  * show the dominant state that was most present across that day
  * are not meant to be constantly reinterpreted through today's baseline

## UI Surfaces

### Now

The `Now` screen currently includes:

* the live state title
* a short plain-language state line
* the animated ambient entity
* a 3-week calendar memory view
* a Pi connection indicator

#### Calendar behavior

The calendar is designed to behave like a memory of recent health-state patterns:

* **Today**
  * shown as a segmented circle
  * each segment reflects how much of the day a state has occupied
  * the percentages are time-based, not just count-based
* **Previous days**
  * shown as one dominant daily state color
  * represent the state that was most present that day
* **No-data / future days**
  * shown with a separate muted visual treatment
  * do not fall back to fake neutral

Users can move through:

* `This Week`
* `Last Week`
* `2 Weeks Ago`

### Explanation

The `Explanation` screen is meant to make the live state understandable without becoming overly clinical.

Current sections include:

* `Most Relevant Signals`
  * based on the current read
  * highlights the strongest current or overnight signals affecting the state
* `What This May Mean`
  * plain-language interpretation of the live read
* `Pattern Insight`
  * weekly context using recent daily state history

Explanation behavior now also accounts for:

* no-data / low-data new-day moments
* overnight signal wording like `Breathing Overnight`
* state-specific language that is simpler and less system-like

### Trends

The `Trends` view is a weekly wellness view of the last 7 days.

Current trends include:

* recovery / HRV
* resting heart rate
* movement
* sleep duration
* sleep quality

Trends are designed to:

* show a past-week view rather than a single current reading
* stay visually consistent across cards
* keep missing days visible instead of silently collapsing them away
* use calmer-mode-friendly summaries when accessibility settings are enabled

### Settings

The `Settings` screen currently includes:

* sensitivity controls
* state preview controls
* HealthKit read status
* last refresh / last successful read timestamps
* Pi send log + connection info
* per-state ambient brightness overrides
* accessibility controls
* developer-only debug snapshot and classifier reasoning

The settings language has also been updated to more clearly explain:

* that the app is a wellness interpretation
* that overnight sleep signals apply to the wake-up day
* that preview mode does not alter saved live history

## Accessibility

The app currently supports:

* `Calmer Mode`
* `Reduce Motion`
* `Larger Text`
* `Higher Contrast`

These settings change presentation and readability, not the underlying classifier logic.

## Preview and Demo Tooling

### State Preview

`State Preview` is for testing and presentation:

* it previews a chosen state on the phone
* it can send that previewed state to the Pi ambient object
* it does **not** rewrite saved live history

### Demo Mode

`Demo Mode` provides deterministic demo datasets for presentation and debugging.

It is kept separate from live history so it does not permanently contaminate:

* calendar memory
* weekly state history
* live snapshot context

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

* `Ambient-Health-PI/`
  * FastAPI bridge for smart-bulb control
  * routes for `POST /set_light`, `OPTIONS /set_light`, `GET /health`, `POST /turn_on`, and `POST /turn_off`
  * warm Kasa-device reuse, fallback rediscovery, duplicate skipping, and latest-only request collapsing

## iOS Setup

1. Open [Ambient Health Interface.xcodeproj](/Users/nathanmcmillan/Desktop/XCodeFiles/Ambient%20Health%20Interface/Ambient%20Health%20Interface.xcodeproj) in Xcode.
2. Run on a physical iPhone for real HealthKit behavior.
3. Grant Health permissions when prompted.
4. If you are using the Pi bridge, make sure the iPhone can reach the configured bridge URL.

## Pi Backend Setup

The Pi bridge lives in [Ambient-Health-PI/README.md](/Users/nathanmcmillan/Desktop/XCodeFiles/Ambient%20Health%20Interface/Ambient-Health-PI/README.md).

## Suggested Demo / Validation Checklist

Before presenting or pushing a final build, the most important sanity checks are:

1. Verify a recent overnight sleep session lands on the **wake-up day** everywhere.
2. Verify the current-day wheel fills by how long each state lasted.
3. Verify previous-day calendar circles stay dominant-state only.
4. Verify a brand-new day without enough data shows `No Data Yet` behavior instead of fake neutral.
5. Verify the Pi bridge still responds to `OPTIONS /set_light` and `POST /set_light` if you are demoing the light.

## Notes and Limitations

* This is a wellness-oriented prototype, not a medical device.
* Signal quality depends on Apple Health availability, recency, and what the user actually tracks.
* Midnight boundary behavior is intentionally conservative when a new day has not gathered enough meaningful data yet.
* The Pi hardware path is currently designed around one bridge and one bulb.
