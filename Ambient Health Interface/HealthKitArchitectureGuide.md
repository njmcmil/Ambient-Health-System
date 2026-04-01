# Ambient Health Interface: HealthKit and App Architecture Guide

## Purpose

This app turns Apple Health data into an ambient state that can drive the on-screen object and the connected Pi light output.

The current implementation is intentionally split into two layers:

1. Health data collection and interpretation
2. Visual expression of the interpreted state

That split makes it easier to keep the app feeling atmospheric instead of turning the main screen into a dashboard.

---

## High-Level Flow

The app works in this order:

1. `AmbientHealthStore` requests HealthKit read access
2. HealthKit queries return recent movement, cardio, respiratory, sleep, and recovery data
3. The store converts those values into a `Snapshot`
4. The snapshot is classified into a `ColorHealthState`
5. The selected state drives:
   - the ambient object
   - explanation copy
   - daily and intraday history views
   - the Pi light output through `PiController`

If a signal is missing, the store treats it as optional rather than failing the whole refresh.

---

## Core Files

### `AmbientHealthStore.swift`

This is the main engine of the app.

Responsibilities:

- manages HealthKit authorization
- loads current-day and multi-day health data
- builds the latest `Snapshot`
- builds trend data for charts and history surfaces
- classifies the snapshot into a `ColorHealthState`
- exposes published state for SwiftUI
- sends the current state to the Pi controller

Main types inside the store:

- `Snapshot`
  A single interpreted health reading window for "now"
- `TrendReport`
  Multi-day and intraday series used by Trends and the calendar history
- `SleepStageBreakdown`
  Normalized sleep-stage summary for total sleep, deep, REM, awake, and efficiency
- `SensitivityProfile`
  Runtime tuning for how strongly the app reacts to HealthKit changes

### `ContentView.swift`

This is the top-level coordinator.

Responsibilities:

- owns the `AmbientHealthStore`
- owns the selected tab
- passes sensitivity controls into the store
- hosts the bottom navigation and main screen switching

### `AmbientHealthNowComponents.swift`

This file contains the minimal ambient home screen.

Responsibilities:

- background
- current-day calendar/history card
- ambient reference object
- current state label and short line
- connect/refresh action row

Design note:
The `Now` screen is intentionally lightweight. It should feel like a glanceable state surface, not the place where every raw metric lives.

### `AmbientHealthDetailViews.swift`

This file holds the deeper inspection views.

Responsibilities:

- `Trends`
- `Explanation`
- `Settings`
- shared bottom bar

This is where the more explicit data interpretation belongs.

### `AmbientHealthFeatureSupport.swift`

This file contains view-support logic and text generation helpers.

Responsibilities:

- tab metadata
- short state copy
- explanation summaries
- explanation bullets
- pattern insight generation

This keeps the views smaller and makes the explanation layer easier to evolve separately from HealthKit querying.

---

## HealthKit Signals in Use

The app currently reads from these Apple Health categories when available:

### Movement

- steps
- active energy burned
- exercise time
- walking/running distance
- flights climbed

### Cardio and recovery

- current heart rate
- resting heart rate
- walking heart rate average
- HRV

### Respiratory and strain

- respiratory rate
- blood oxygen when available
- sleeping wrist temperature when available

### Sleep

- sleep duration
- sleep-stage breakdown from sleep analysis
  - awake
  - core
  - deep
  - REM
  - unspecified asleep time
  - in bed

### Context signals

- mindful sessions
- hydration

Important implementation detail:
not every Apple Watch or iPhone configuration returns every signal. The app is built so unsupported or temporarily empty signals simply reduce the amount of context available instead of breaking classification.

---

## How the App Thinks About Sleep

Sleep is deeper than a single "hours slept" number in this project.

The store derives:

- total sleep hours
- in-bed hours
- awake hours
- deep sleep percentage
- REM percentage
- awake percentage
- sleep efficiency

That lets the app distinguish between:

- long but fragmented sleep
- shorter but efficient sleep
- stronger restorative sleep
- lighter, more fatigue-prone sleep

This matters because the ambient state is trying to express recovery quality, not just quantity.

---

## State Classification Model

The app maps HealthKit signals into these ambient states:

- `blue`
  strong recovery
- `green`
  healthy / steady
- `yellow`
  under-moved
- `purple`
  stress-loaded
- `orange`
  fatigue / softer recovery
- `red`
  stronger strain
- `gray`
  neutral / mixed baseline

The classification is heuristic, not medical.

In practice, the model blends three broad buckets:

1. movement
2. stress / load
3. recovery

Examples:

- `blue` tends to require stronger recovery markers such as solid sleep staging, steadier HRV, and calmer resting signals
- `yellow` leans on low movement
- `purple` leans on stress-like cardio / HRV / respiratory behavior
- `orange` leans on weaker sleep quality or recovery debt
- `red` is reserved for stacked strain signals

The logic is intentionally transparent enough to iterate on. If the feel of the object is off, the first place to inspect is usually the threshold section in `classify(snapshot:)`.

---

## Sensitivity Model

Sensitivity is not just a visual setting. It changes how the classification engine reacts to real HealthKit data.

The four controls are:

- `Stress Response`
- `Movement Response`
- `Recovery Response`
- `Overall Responsiveness`

Recommended defaults are tuned around the current Apple Watch SE 3-oriented signal mix:

- strong emphasis on sleep, HRV, resting heart rate, and movement
- less dependence on signals that may be unavailable on some devices

Presets:

- `Gentle`
  more stable, less reactive
- `Recommended`
  balanced for current hardware assumptions
- `Responsive`
  reacts to smaller changes sooner
- `Custom`
  created once sliders diverge from preset values

---

## Authorization Model

HealthKit read authorization is a little nuanced.

The app now uses:

- authorization request status to decide whether Health access still needs to be requested
- actual query results to determine whether signals are readable or simply have no recent samples

That is why the Settings screen uses terms like:

- `Readable`
- `No recent data`
- `Waiting for access`

instead of pretending every read type can be cleanly marked as granted or denied individually.

---

## Tab Philosophy

### `Now`

Minimal ambient readout.

Use this screen when the goal is:

- quick glanceability
- emotional tone
- state recognition

This screen intentionally avoids raw metric density.

### `Trends`

This is where temporal structure lives.

Use this screen to inspect:

- weekly state trail
- sleep trend
- HRV trend
- resting heart rate trend
- movement trend
- sleep-stage balance trend

### `Explanation`

This screen translates the current state into interpretable language.

It answers:

- what signals are probably driving the current state
- what this pattern may mean
- what the recent pattern suggests overall

### `Settings`

This is the operational screen.

It holds:

- sensitivity presets
- advanced sensitivity sliders
- HealthKit status
- readable signal summary

---

## History Surfaces

There are two different history ideas in the app:

### Weekly history

Shown as day circles in the calendar row.

This gives a compact summary of how the ambient state has moved across the week.

### Intraday history

Shown inside the small "today" wheel.

This represents the state progression through the current day rather than flattening the whole day into one color.

This distinction keeps "today's changes" separate from "this week's pattern."

---

## Why the Store Keeps Optional Data Optional

HealthKit data is messy in normal use:

- some days have no sleep stages yet
- some signals are not supported on a given watch
- some categories may be enabled but still have no samples in the current window
- some queries legitimately return empty results

The app treats those as missing context, not fatal errors.

That design choice is important because the ambient object should degrade gracefully as data availability changes.

---

## Typical Iteration Points

When changing behavior, these are the main places to work:

### To change the feel of the ambient state

Edit:

- `classify(snapshot:)` in `AmbientHealthStore.swift`

### To change what data is read

Edit:

- `healthTypes`
- snapshot query helpers in `AmbientHealthStore.swift`

### To change the explanation language

Edit:

- `explanationSummary`
- `explanationBullets`
- `patternInsight`
- `explanationDrivers`

### To change what shows in tabs

Edit:

- `AmbientHealthNowComponents.swift`
- `AmbientHealthDetailViews.swift`

---

## Current Design Direction

The app has moved away from being a simulation prototype and is now structured as:

- a real HealthKit-driven ambient interface
- a deeper trend and explanation system
- a settings surface for tuning responsiveness
- a Pi-connected output layer for physical expression

That means the codebase is now best thought of as a small interpretation engine plus a visual expression layer.

---

## Practical Testing Notes

For live testing:

1. run the app on a physical iPhone
2. connect Health access
3. generate or sync Apple Watch data
4. refresh the app
5. inspect `Now`, `Trends`, `Explanation`, and `Settings`

Because Apple Watch data flows through the paired iPhone's Health database, the iPhone app is the right place to validate the current implementation.

---

## Good Next Extensions

Reasonable next steps from here:

- add a dedicated signal drill-down screen
- expose which top 2 to 3 signals are currently driving the state
- add baseline comparison instead of only absolute thresholds
- add day selection on the calendar row
- make explanations reference trend direction, not just current values

The existing file split should support those additions without forcing another large refactor.
