# GTA Studio — No-Code Open-World Engine (Godot 4 Base)

Yeh repository **Godot 4** ke upar bana ek **Customized Open-World / GTA-Style Starter Engine + No-Code Visual City Builder Plugin (`GTA Studio`)** hai.

Iska maqsad simple hai: **Unity/Unreal jaise hazaaron confusing menus aur coding ke bina**, seedha **1-Click Buttons aur Sliders** se apna GTA-style 3D Open-World game banana!

---

## Kya-Kya Pre-Built Hai? (Ready Out-of-the-Box)

1. **`GTA Studio` No-Code Builder Dock (`addons/gta_studio/`)**
   - Godot kholte hi right side me **`GTA Studio`** panel apne-aap khul jaata hai.
   - **1-Click City Spawner:** `+ Straight Road`, `+ 4-Way Crossroads`, `+ Glass Skyscraper`, `+ Neon Shop`, `+ Stunt Jump Ramp`, `+ Streetlight`, `+ Palm Tree`.
   - **1-Click Vehicle Spawner:** `+ Sports Car (Infernus GT)`, `+ Police Cruiser (Pursuit AI)`, `+ Offroad SUV`, `+ AI Traffic Taxi`.
   - **1-Click AI & Missions:** `+ Sidewalk Pedestrian NPC`, `+ Glowing Yellow Mission Checkpoint ($)`, `+ Switchable Protagonist`.
   - **1-Click Sky Vibe:** `Sunset` (Los Santos Golden Hour), `Noon`, `Night` (Neon Midnight).

2. **GTA 5 Core Gameplay Systems**
   - **GTA 5 Style 3-Character Sky Switch (`1` / `2` / `3` Keys):** Franklin, Michael aur Trevor ke beech bilkul GTA 5 jaisa aasmaan me zoom-out hokar dusre character par land hone wala camera transition!
   - **3rd-Person Walk, Sprint & Smooth Camera:** `SpringArm3D` collision-safe camera + laptop trackpad & mouse dono ke liye smooth controls.
   - **Car Steal & 4-Wheel Physics Driving (`F` Key):** Kisi bhi parked ya chalte hue AI traffic car ke paas jaakar `F` dabao — real 4-wheel suspension, **Handbrake Drift (`Space`)**, **Nitro Boost (`Shift`)**, **Headlights (`L`)**, aur **Siren (`H`)**!
   - **Police Wanted Stars (`★ ★ ★ ★ ★`) & Pursuit AI:** Traffic car hijack karne ya pedestrian ko hit karne par Wanted Stars badhte hain aur **LSPD Police Cruiser** red/blue siren chala kar tumhara peecha karti hai!
   - **GTA 5 Style HUD & Live 3D Minimap Radar:** Bottom-left me live 3D Minimap + Health/Armor bars, top-right me `$ Cash` + Wanted Stars, aur gaadi chalate waqt digital `KM/H` Speedometer!
   - **1-Slot Custom `.glb` 3D Model Support (Zero Coding):** Jab high-detail 3D cars/characters/buildings lagane hon (jaise Kenney, Quaternius ya Sketchfab se free `.glb` download karke), bas Inspector me **`Custom Car Model` / `Custom Character Model` / `Custom Prop Model`** wale dabbe me drag-and-drop kar do!

---

## Kaise Chalayein? (Sirf 2 Minute Setup)

1. **Godot 4 Download karo (Sirf ~70 MB, Free, No Install):**
   - PC/Laptop: [godotengine.org/download](https://godotengine.org/download) se **Godot 4 (Standard version, .NET nahi)** download karo.
   - Android Phone/Tablet: Play Store se official **Godot Editor 4** install kar sakte ho (is game me mobile touch buttons bhi built-in hain!).
2. Is repository (`Game-Engine`) ko download / clone karo.
3. Godot kholo -> **Import** dabao -> is folder ke andar **`project.godot`** select karke **Import & Edit** dabao.
4. Upar right corner me **Play (`F5`)** dabao (ya `GTA Studio` panel me **`▶ PLAY OPEN WORLD`** button dabao) — aur seedha Mini Los Santos me khelna shuru karo!

---

## In-Game Controls

| Key / Button | On Foot (Paidal) | In Vehicle (Gaadi Me) |
| :--- | :--- | :--- |
| **W / A / S / D** or **Arrows** | Walk / Move | Accelerate / Steer / Brake-Reverse |
| **F** or **E** | Nearest Car me baitho / Hijack karo | Car se bahar niklo |
| **Shift** | Fast Sprint | Nitro Boost |
| **Space** | Jump | Handbrake Drift |
| **1 / 2 / 3** | GTA 5 Sky-Zoom Character Switch | Exit & Sky-Zoom Switch |
| **L** | — | Headlights On / Off |
| **H** | — | Siren / Horn Toggle |
| **T** | Sunset / Noon / Night badlo | Sunset / Noon / Night badlo |
| **Esc** | Mouse Cursor dikhao / chhupao | Mouse Cursor dikhao / chhupao |
| **F1** | Controls Help Box chhupao/dikhao | Controls Help Box chhupao/dikhao |

---

## Folder Structure

```text
Game-Engine/
├── project.godot                     # Godot 4 main configuration
├── addons/gta_studio/                # Custom No-Code "GTA Studio" Editor Plugin
├── scenes/
│   ├── main_city.tscn                # Ready-to-play Mini Los Santos Open World
│   └── prefabs/                      # Drag-and-drop Cars, Player, NPCs, Props, Missions
└── scripts/
    ├── core/game_manager.gd          # Cash, Wanted Stars, 3-Char Sky Switch, Input setup
    ├── player/gta_character.gd       # 3rd-Person Player Controller
    ├── vehicles/gta_vehicle.gd       # 4-Wheel Raycast Car + Drift + Nitro + AI Police/Traffic
    ├── world/                        # Modular City Props, Pedestrians, Missions, Sunset Sky
    └── ui/gta_hud.gd                 # Live 3D Minimap Radar, Cash, Stars, Speedometer, Touch UI
```
