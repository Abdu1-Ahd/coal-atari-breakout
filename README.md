# Atari Breakout 🧱 (Computer Organization and Assembly Language)

A clone of the classic Atari Breakout game written entirely in **16-bit x86 DOS Assembly** (NASM). It utilizes direct VGA memory mapping (Mode 13h) for rendering pixels and low-level BIOS interrupts for input handling and timing.

## Features

- **Mode 13h VGA Graphics:** Direct access to `0A000h` video memory for fast rendering of paddles, balls, and bricks.
- **Hardware Interrupts:** Keyboard polling using INT 16h and timing via BIOS clock ticks.
- **Physics & Collision:** Custom 16-bit algorithms for ball movement, wall bouncing, paddle reflection, and brick destruction.
- **Score System:** Rendering numerical digits directly to the screen and tracking high scores in memory/file.
- **Standalone:** Packaged with DOSBox and NASM assembler for a one-click execution environment.

## Screenshots

![Home screen](assets/Home%20screen.png)
![In Game](assets/In%20Game.png)
![End screen](assets/End%20screen.png)

## Prerequisites

- Windows Environment (for the `run.bat` wrapper)
- Alternatively, you can run the generated `breakout.com` via any DOSBox installation.

## How to Play

1. Run `run.bat` to automatically assemble `breakout.asm` into `breakout.com` and mount it inside DOSBox.
2. Use Left/Right arrow keys or `A`/`D` to move the paddle.
3. Don't let the ball touch the bottom floor! Break all the bricks to win.
