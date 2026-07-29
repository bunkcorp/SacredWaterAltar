# Sacred Water Altar — Architecture

Custom visionOS mixed-reality shrine app built from the Apple sample patterns in this workspace.

## Scenes

| Scene | ID | Style |
|-------|-----|--------|
| Launch window | `ContentWindow` | Plain `WindowGroup` |
| Shrine | `ImmersiveSpace` | `.mixed` |

Flow: load assets in the window → **Enter Altar** opens the immersive space and dismisses the window → **Exit** reverses that.

## Shrine composition

```
ShrineRoot
├── Environment (floor, backdrop plane, point lights)
├── Altar (wood base/top, red cloth, gold trim)
├── GoldenBuddha_Anchor
├── SeatedBuddha1973_Anchor
├── Vajrasattva_Anchor
└── BowlAnchor_1…7
    └── Bowl_N + Water_N
```

## Assets

| Resource | Role |
|----------|------|
| `Golden_Buddha_Statue.usdz` | Center statue |
| `1973.usdz` | Left seated Buddha |
| `Vajrasattva_Full.usdz` | Right statue (bronze/gold material at runtime) |
| `Tibetan_Singing_Bowl.usdz` | Template cloned 7× |
| `bowl_tone_1…7.wav` | Distinct spatial strike tones |

All imported models are scaled from visual bounds and planted on `y = 0` before anchoring.

## Interaction

- `BowlIndexComponent` marks each bowl
- `SpatialTapGesture().targetedToAnyEntity()` resolves the bowl index
- Strike → spatial tone + expanding ripple rings + short water/bowl pulse
- Ambient water bob runs on a lightweight async loop per bowl

## Debug

Launch argument `-autoEnterAltar` (DEBUG only) auto-enters the immersive shrine after assets load.
