# Sacred Water Altar

A visionOS mixed-reality shrine with:

- Golden Buddha Statue (center)
- 1973.85 Seated Buddha (left)
- Vajrasattva Full (right, bronze/gold material at runtime)
- Seven Tibetan singing bowls with animated water, ripples, and unique tones

## Requirements

- Xcode 26.6+ with visionOS 26.0+ SDK (built against visionOS 26.5)
- Apple Vision Pro Simulator (or device)

## Open & Run

1. Open `SacredWaterAltar.xcodeproj`
2. Select scheme **SacredWaterAltar**
3. Choose an **Apple Vision Pro** simulator destination
4. Set your Development Team if signing requires it
5. Build & Run (⌘R)

## In-app flow

1. Wait for “Shrine ready”
2. Tap **Enter Altar**
3. Look at a bowl and tap to strike it
4. Tap **Exit** in the immersive controls to return

## Project layout

```
SacredWaterAltar/
├── SacredWaterAltar.xcodeproj
├── README.md
├── CREDITS.md
└── SacredWaterAltar/
    ├── SacredWaterAltarApp.swift
    ├── Models/
    ├── Views/
    ├── Scenes/
    └── Resources/
        ├── Models/   # USDZ assets
        ├── Audio/    # bowl_tone_1...7.wav
        └── Assets.xcassets
```

## Notes

- Assets are normalized from visual bounds so Sketchfab scale differences do not break placement.
- Vajrasattva’s USDZ lost source vertex colors; the app applies a warm bronze/gold material.
- Vajrasattva is still a dense mesh (~1.7M verts). If Simulator performance is poor, prefer device testing or a decimated copy later.
- Debug launch argument: `-autoEnterAltar` automatically opens the immersive shrine after assets load.
