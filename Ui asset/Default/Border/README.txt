# Godot Main Menu — Matrix Rain & Parallax Drift
# Godot 4.x (GDScript)

## Files
- MatrixRain.gd         — draws the falling character rain on a Node2D
- ParallaxMouseDrift.gd — makes any node drift with the mouse for parallax depth

---

## Scene Tree

```
MainMenu (Control, full-screen anchor)
├── BackgroundImage (TextureRect)        ← your static cyberpunk grid image
│   └── ParallaxMouseDrift.gd           ← drift_strength = -18
├── MatrixRain (Node2D)                  ← rain script goes here
│   └── ParallaxMouseDrift.gd           ← drift_strength = -9
└── UILayer (CanvasLayer or Control)     ← title + buttons
    └── ParallaxMouseDrift.gd           ← drift_strength = 5
```

---

## Step-by-step Setup

### 1. BackgroundImage
- Add a TextureRect, set your background image as the texture.
- Layout → Full Rect anchor (Ctrl+L → Full Rect).
- Stretch Mode → Cover.
- Modulate → set Alpha to ~70 (28%) so buttons stay readable.
- Add ParallaxMouseDrift as a child script node, set drift_strength = -18.

### 2. MatrixRain Node
- Add a Node2D named "MatrixRain".
- Attach MatrixRain.gd to it.
- In the Inspector, tune:
  - rain_opacity = 0.55
  - drop_speed_min = 60, drop_speed_max = 120
  - trail_length = 20
- Add ParallaxMouseDrift as a child, set drift_strength = -9.

### 3. UILayer
- Add a Control (or CanvasLayer) for your title label and buttons.
- Add ParallaxMouseDrift as a child, set drift_strength = 5.
- Note: if you use CanvasLayer, switch ParallaxMouseDrift to target
  the CanvasLayer's offset property instead of position (see note below).

### 4. ParallaxMouseDrift — CanvasLayer note
If your UILayer is a CanvasLayer, replace the position line in _process with:
  (owner as CanvasLayer).offset = _origin + _current_offset
And change _origin capture to:
  _origin = (owner as CanvasLayer).offset

---

## Tuning Reference

| Property          | Effect                                      | Suggested range |
|-------------------|---------------------------------------------|-----------------|
| drift_strength    | Max pixel shift at screen edge              | ±5 to ±20      |
| smoothing         | Lerp speed (higher = snappier)              | 3.0 – 8.0      |
| rain_opacity      | MatrixRain overall transparency             | 0.4 – 0.7      |
| drop_speed_min/max| How fast columns fall (px/sec)              | 40 – 160       |
| trail_length      | Number of chars per column                  | 10 – 30        |
| respawn_chance    | How quickly dead columns restart            | 0.01 – 0.03    |
| column_spacing    | Horizontal gap between rain columns (px)    | 12 – 18        |

---

## Colour Customisation (MatrixRain.gd)

Four exported Color properties control the gradient along each trail:

  color_head   = white            ← the leading character (brightest)
  color_bright = pale green       ← top of the trail
  color_mid    = #00cc66          ← middle of the trail
  color_dim    = transparent      ← tail fades out completely

Change color_mid to blue/purple if you want a different matrix colour scheme.
