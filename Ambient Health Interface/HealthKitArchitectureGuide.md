# Ambient Health Interface: HealthKit Architecture Guide

## Purpose

Ambient Health Interface turns Apple Health signals into a stateful ambient experience:

1. infer a `ColorHealthState` from live + baseline-aware health context
2. render that state through the on-screen reference entity
3. optionally mirror the state to a Pi bridge for physical light output

This system is wellness-oriented and interpretive, not diagnostic.

---

## Current High-Level Flow

1. `AmbientHealthStore` requests and tracks HealthKit read access.
2. Query layer builds:
   - a live `Snapshot`
   - a multi-day `TrendReport`
3. Classifier maps snapshot + baseline + sensitivity into one state:
   - `Restored`, `Grounded`, `Neutral`, `Low Energy`, `Stressed`, `Drained`, `Overloaded`
4. UI reads `displayedState`:
   - live state in normal mode
   - forced state in preview mode
5. `PiController` sends the mapped state color/brightness payload to `/set_light` on the configured bridge.

Missing signals are treated as partial context, not hard failure.

---

## Code Layout (Current)

- `HealthStore/`
  - `AmbientHealthStore.swift`
  - `AmbientHealthStore+Models.swift`
  - `AmbientHealthStore+Queries.swift`
  - `AmbientHealthStore+Classifier.swift`
- `Reference/`
  - `AmbientHealthReferenceView.swift`
  - `ReferenceShape.swift`
  - `ReferenceMotionProfile.swift`
- `NowUI/`
  - `AmbientNowView.swift`
  - `AmbientNowCalendarView.swift`
- `DetailViews/`
  - `AmbientTrendsView.swift`
  - `AmbientExplanationView.swift`
  - `AmbientSettingsView.swift`
  - `AmbientDetailViewSupport.swift`
- `Support/`
  - `AmbientExplanationSupport.swift`
  - `AmbientPreviewSupport.swift`
  - `AmbientNavigationSupport.swift`
  - `AmbientDateFormatting.swift`
- `Controllers/`
  - `PiController.swift`
- `Models/`
  - `ColorHealthState.swift`

---

## Health Data Inputs

The app can read (when available and authorized):

- heart rate variability
- resting heart rate
- current heart rate
- respiratory rate
- sleep analysis and sleep stages
- step count
- exercise minutes
- optional context signals like wrist temperature

The app handles gaps gracefully:

- unsupported signal -> skipped
- authorized but empty window -> treated as no recent data
- available signal -> contributes to classification/trends/explanation

---

## Classification Model

The classifier blends three major dimensions:

- recovery quality
- activation/strain
- movement/energy rhythm

The model is sensitivity-aware and baseline-relative, with workout-aware protections to reduce false stress spikes from exercise sessions.

Sensitivity configuration can make states appear sooner/later without changing the state taxonomy.

---

## UI Semantics (Current)

### Now

- shows current state and animated reference entity
- shows state-aware calendar history
- shows ambient object connection indicator

### Explanation

- `What This May Mean`: current-state interpretation
- `Pattern Insight`: weekly-pattern interpretation
- preview mode swaps live explanations for example interpretations

### Trends

- weekly context first (`This Week` summary)
- focused cards below for:
  - HRV
  - resting heart rate
  - energy rhythm
  - sleep duration
  - sleep quality

Important semantics:

- `This Week` summary is weekly-average language (no latest/current framing).
- Detailed cards can show a most-recent point (for quick recency context).

### Settings

- sensitivity controls
- state preview controls
- accessibility controls
- HealthKit status/readability surface

---

## Accessibility Model

Current accessibility options:

- Calmer Mode
- Reduce Motion
- Larger Text
- Higher Contrast

These are presentation-layer adjustments and do not alter core health signal ingestion.

---

## Preview Mode Behavior

Preview mode is intentionally isolated from live interpretation:

- UI renders the chosen preview state
- explanation/trends switch to example-oriented preview content
- returning to live mode restores live state routing
- Pi output can temporarily mirror preview state (then return to live routing)

---

## Pi Bridge Integration

`PiController` owns:

- connection status publishing
- payload mapping from `ColorHealthState` to bridge color/brightness values
- POST request to bridge endpoint (`/set_light`)

Operational note:

- App and bridge must be reachable on the same network path.
- Bridge failures should not block UI state rendering.

---

## Validation Checklist

For practical verification on device:

1. Launch on physical iPhone.
2. Grant HealthKit access.
3. Refresh and confirm snapshot/trend loading.
4. Confirm `Now` state updates and reference behavior.
5. Confirm `Explanation` and `Trends` language matches the displayed mode (live vs preview).
6. Confirm Settings preview toggles and accessibility options.
7. Confirm Pi bridge sends and connection indicator behavior.

---

## Scope Reminder

This project is a strong prototype architecture for ambient wellness interpretation.  
It is not intended as medical-grade inference or clinical decision support.
