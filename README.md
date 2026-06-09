# PuttTrack

A React Native (Expo) iPhone-first putting statistics tracker.

## Features
- **On-course input**: distance picker, arched break slider, ski-slope hill slider, double-break buttons, dartboard miss selector
- **Auto-advance**: moves to next putt after recording; advances to next hole automatically on "Holed"
- **Putt history nav**: ‹ › arrows to review and edit any previous putt in the round
- **Pre-round setup**: course name, putter selection, stimp (6.5–13.5), wind, weather
- **Strokes Gained**: every putt compared to PGA Tour baseline (Mark Broadie methodology)
- **Statistics**: make % by distance bracket vs tour, SG total, miss tendency, putts per hole
- **Settings**: metres / feet toggle, haptic feedback, putter management

## Stack
- Expo SDK 52 + expo-router (file-based)
- expo-sqlite (local only, no cloud needed)
- react-native-svg (sliders + dartboard)
- zustand (app state)
- expo-haptics

## Getting Started

```bash
npm install
npx expo start
# Press i for iOS Simulator, or scan QR with Expo Go
```

## Project Structure
```
app/
  (tabs)/          # Tab nav: On Course | Games | Statistics | Settings
  round/
    setup.tsx      # Pre-round: stimp, wind, weather, putter
    input.tsx      # Main on-course putt input screen
    summary.tsx    # Post-round stats summary
components/
  CurvedSlopeSlider  # Arched SVG break slider (snaps at 0.5%)
  HillSlider         # Ski-slope SVG uphill/downhill slider
  DoubleBreakButtons # S-curve double-break selectors
  DistancePicker     # Horizontal snap-scroll distance list (<0.5–30 m)
  DartboardMiss      # SVG dartboard miss/result selector
  StrokesGainedChart # Make % vs PGA Tour bar chart
data/strokesGained   # PGA Tour make% baseline table (Mark Broadie)
db/                  # SQLite schema + queries
store/               # Zustand: settingsStore + roundStore
utils/               # sgCalculator, unitConverter
```
