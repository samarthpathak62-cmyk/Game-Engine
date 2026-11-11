@echo off
title GTA Studio V - Direct OpenGL3 Launcher (Zero Crash Mode)
cd /d "%~dp0"

set "GODOT_EXE="

if not "%~1"=="" (
    set "GODOT_EXE=%~1"
    goto :run
)

for %%F in ("Godot*.exe" "..\Godot*.exe" "%USERPROFILE%\Downloads\Godot*\Godot*console.exe" "%USERPROFILE%\Downloads\Godot*.exe" "%USERPROFILE%\Desktop\Godot*\Godot*.exe" "%USERPROFILE%\Desktop\Godot*.exe") do (
    if exist "%%~fF" (
        set "GODOT_EXE=%%~fF"
        goto :run
    )
)

echo ====================================================================
echo   Godot.exe automatic nahi mila!
echo   Easy Tarika:
echo   1. Apna Godot_v4.x_win64.exe copy karke is Game-Engine folder me rakh do, YA
echo   2. Godot.exe ko utha kar (Drag and Drop) is Play_Direct_Game.bat ke upar chhod do!
echo ====================================================================
pause
exit /b 1

:run
echo Launching Los Santos V + 3D World Engine in Crash-Proof OpenGL3 Mode...
echo Using Godot: "%GODOT_EXE%"
start "" "%GODOT_EXE%" --path "%~dp0" --rendering-driver opengl3
