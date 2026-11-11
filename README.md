# Los Santos V — GTA Studio Open-World Engine (Godot 4.7 | Intel UHD Crash-Proof Edition)

Ek **100% Real 3D Models (`.glb`)** wala **GTA 5 Style Open-World Game + No-Code 3D World Engine**, khaas **Windows 11 + Intel(R) UHD Graphics** par **bina crash / bina lag** smooth chalne ke liye optimize kiya gaya!

---

## 🚨 AGAR PEHLE GODOT FORCE-CLOSE HUA THA TO YE 2 STEP KARO:

1. **Latest Code Pull / Download karo** (`arena/1c0c0bf8-game-engine` branch).
2. Folder ke andar **`Fix_Crash_Clean_Cache.bat`** par **Double-Click** karo!
   *(Ye purane crash wala corrupted `.godot` shader/import cache clean kar dega).*
3. Ab **Godot 4.7** kholo — project `Compatibility (OpenGL 3)` mode me **2 second me bina band huye** khul jayega! Simply **`F5` (Play)** dabao!
   - **Bonus Direct Shortcut:** Agar bina Godot Editor khole seedha Game + 3D World Engine chalana ho, to apna `Godot_v4.7...exe` is folder me rakh kar **`Play_Direct_Game.bat`** double-click kar do!

---

## 🛠 Humne Force-Close Crash Kaise Fix Kiya (v2.1 Technical Summary)

| Problem (Pehle kyun band ho raha tha) | v2.1 Solution (Ab kyun nahi band hoga) |
|---|---|
| **Vulkan `Forward+` + ReflectionProbe + SSAO** Intel UHD Windows driver ko hang (`VK_ERROR_DEVICE_LOST`) kar deta tha | **`gl_compatibility` (OpenGL 3 / ANGLE)** renderer default set kiya — Intel UHD par 100% rock-solid! |
| **2 Unoptimized Sketchfab Cars** (`682` nodes, `336` surfaces, `53` textures, `KHR_materials_transmission` glass shader) import par freeze karti thi | Unhe hata kar **Clean Game-Ready 3D `.glb` Supercars & SUVs** (`Pegassi Zentorno`, `Infernus GT`, `Luxury SUV` — sirf 5–6 nodes, `1.5 MB` total!) lagayi! |
| **Minimap `SubViewport`** poore 3D sheher ko har frame **2 baar** render kar raha tha | Fast **GTA 5 2D Vector GPS Radar** lagaya (Roads, Beach, Ocean, Flashing Police Blips, Mission Blips) — 0% extra GPU load! |
| **`@tool` Setter Rebuild Loop** scene khulte hi har building/car ko 3–4 baar reload karta tha | **`is_node_ready()` guards + Static `PackedScene` & `ShaderMaterial` Cache** lagaya — Editor turant smooth khulta hai! |

---

## 🎮 Full Controls (Mouse + Keyboard)

- **Launch par GTA 5 Main Menu:**
  - `▶ PLAY LOS SANTOS` — Seedha game start karo!
  - `🛠 3D WORLD ENGINE BUILDER` — Bina coding apna Los Santos map banao!
  - `⚙ GRAPHICS & MOUSE SETTINGS` — `Fast (60 FPS)` / `High` / `Ultra`, Mouse Sensitivity, Fullscreen!
- **Walking & Combat:**
  - **Mouse Move:** 360° Smooth GTA Camera
  - **Right-Click (Hold) + Left-Click:** Over-the-Shoulder Rifle Aim + Shoot!
  - **W / A / S / D:** Chalna (`Shift` = Sprint, `Space` = Jump, `C` = Combat Roll, `Q` = Weapon Switch)
- **Driving & Action:**
  - **`F` ya `E`:** Kisi bhi 3D Supercar / SUV / Police Car me baitho ya bahar niklo
  - **`Shift`:** Nitro Boost | **`Space`:** Handbrake Drift | **`H`:** Horn / Police Siren | **`L`:** Headlights
- **GTA 5 Special Features:**
  - **`1` / `2` / `3`:** Franklin, Michael aur Trevor ke beech **GTA 5 Sky-Zoom Switch**!
  - **`TAB`:** Kabhi bhi **Live 3D World Engine Mode** kholo (WASD+RightClick se udo, LeftClick se 3D Skyscrapers, Supercars, Ramps, Police, Missions lagao aur `Save World` karo!)
  - **`T`:** Sunset / Sunny Day / Neon Night badlo
  - **`ESC`:** Pause Menu (Spawn Zentorno Supercar, Settings, Engine Mode)
