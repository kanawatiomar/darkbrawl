@echo off
set GODOT=C:\Users\kanaw\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.1-stable_win64.exe
set PROJECT=%~dp0
start "" "%GODOT%" --path "%PROJECT%"
