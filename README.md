# Sacred Water Altar

A shrine app for **visionOS** and **iPhone**, sharing the same 3D scene:

- Golden Buddha Statue (center)
- 1973.85 Seated Buddha (left)
- Vajrasattva Full (right, bronze/gold material at runtime)
- Swayambhu Stupa backdrop
- Three spinning mantra wheels
- Seven Tibetan singing bowls with animated water, ripples, and unique tones

## Platforms

| Platform | Experience |
|---|---|
| **Apple Vision Pro** | Mixed immersive space — walk up to the altar and tap bowls |
| **iPhone** | 3D viewer — drag to orbit, pinch to zoom, tap bowls |

## Requirements

- Xcode 26.6+ with visionOS 26.0+ and iOS 18.0+ SDKs
- Apple Vision Pro Simulator **or** iPhone Simulator / device

## Open & Run

1. Open `SacredWaterAltar.xcodeproj`
2. Select scheme **SacredWaterAltar**
3. Choose a destination:
   - **Apple Vision Pro** simulator for immersive mode
   - **iPhone** simulator or device for the phone viewer
4. Set your Development Team if signing requires it
5. Build & Run (⌘R)

## In-app flow

### visionOS
1. Wait for “Shrine ready”
2. Tap **Enter Altar**
3. Look at a bowl and tap to strike it
4. Tap **Exit** to return

### iPhone
1. Wait for “Shrine ready”
2. Tap **Open Altar**
3. Drag to orbit, pinch to zoom, tap bowls to strike
4. Tap **Exit** to return

## Project layout

```
SacredWaterAltar/
├── SacredWaterAltar.xcodeproj
├── README.md
├── CREDITS.md
└── SacredWaterAltar/
    ├── SacredWaterAltarApp.swift
    ├── Models/
    ├── Views/          # includes PhoneShrineView for iOS
    ├── Scenes/         # ImmersiveSpace used on visionOS only
    └── Resources/
        ├── Models/   # USDZ assets
        ├── Audio/    # bowl_tone_1...7.wav
        └── Assets.xcassets
```

## Notes

- Assets are normalized from visual bounds so Sketchfab scale differences do not break placement.
- Vajrasattva’s USDZ lost source vertex colors; the app applies a warm bronze/gold material.
- Vajrasattva is still a dense mesh (~1.7M verts). If Simulator performance is poor, prefer device testing or a decimated copy later.
- Debug launch argument: `-autoEnterAltar` automatically opens the shrine after assets load.
