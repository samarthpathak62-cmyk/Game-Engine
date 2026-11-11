@echo off
title GTA Studio V - Crash Fix & Cache Cleaner
cd /d "%~dp0"
echo ========================================================
echo   GTA STUDIO V - CORRUPTED GODOT CACHE CLEANER
echo ========================================================
echo.
if exist ".godot" (
    echo Cleaning old/corrupted .godot import & shader cache...
    rmdir /s /q ".godot"
    echo [OK] Purana .godot cache delete ho gaya!
) else (
    echo [OK] Koi purana .godot cache nahi mila - project bilkul clean hai!
)
echo.
echo Ab aap Godot 4 open karke project import kar sakte ho,
echo ya seedha Play_Direct_Game.bat chala sakte ho!
echo ========================================================
pause
