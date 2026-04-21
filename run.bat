@echo off
cd /d %~dp0
echo Assembling Atari Breakout...
.\nasm-2.16.03\nasm.exe -f bin breakout.asm -o breakout.com
if %ERRORLEVEL% NEQ 0 (
    echo Assembly failed!
    pause
    exit /b 1
)
echo Done. Launching DOSBox...
start "" "C:\Program Files (x86)\DOSBox-0.74-3\DOSBox.exe" -conf dosbox.conf -noconsole
