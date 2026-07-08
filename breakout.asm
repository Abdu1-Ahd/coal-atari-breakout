; Atari Breakout - COAL Project
; NASM flat binary COM format for DOSBox
; Bonus: 3 levels, 4 brick colors w/ different scores, hi-score file
; Fixed: write_char now preserves CX (root cause of blank screen bug)

BITS 16
ORG  100h

PLAY_TOP   EQU 3
PLAY_BOT   EQU 22
PLAY_LEFT  EQU 1
PLAY_RIGHT EQU 78
BROWS      EQU 4
BCOLS      EQU 14
BROW1      EQU 4
BSCOL      EQU 4
PADLEN     EQU 6

; entry point
start:
    MOV AX, CS
    MOV DS, AX
    MOV ES, AX
    MOV AH, 00h
    MOV AL, 03h
    INT 10h
    MOV AH, 01h
    MOV CX, 2000h
    INT 10h

main_loop:
    CALL show_welcome
    MOV AH, 00h
    INT 16h
    CMP AL, 1Bh
    JE  done
    CMP AL, 0Dh
    JNE main_loop

    MOV WORD [lives],     3
    MOV WORD [score],     0
    MOV WORD [cur_level], 1
    MOV WORD [spd],       0F000h

level_start:
    CALL reset_bricks
    CALL clear_screen
    CALL draw_border
    CALL draw_bricks
    CALL draw_paddle
    CALL draw_ball
    CALL draw_hud

game_loop:
    MOV CX, [spd]
.delay:
    LOOP .delay

    ; check key
    MOV AH, 01h
    INT 16h
    JZ  no_input
    MOV AH, 00h
    INT 16h

    ; left: arrow or A/a
    CMP AH, 4Bh
    JE  pad_left
    CMP AL, 'a'
    JE  pad_left
    CMP AL, 'A'
    JE  pad_left

    ; right: arrow or D/d
    CMP AH, 4Dh
    JE  pad_right
    CMP AL, 'd'
    JE  pad_right
    CMP AL, 'D'
    JE  pad_right

    CMP AL, 1Bh
    JE  done
    JMP no_input

pad_left:
    MOV AX, [paddleX]
    CMP AX, PLAY_LEFT + 1
    JLE no_input
    CALL erase_paddle
    DEC WORD [paddleX]
    CALL draw_paddle
    JMP no_input

pad_right:
    MOV AX, [paddleX]
    ADD AX, PADLEN
    CMP AX, PLAY_RIGHT - 1
    JGE no_input
    CALL erase_paddle
    INC WORD [paddleX]
    CALL draw_paddle

no_input:
    ; ball frame skip - only move ball every [ball_delay] loops
    INC WORD [ball_cnt]
    MOV AX, [ball_cnt]
    CMP AX, [ball_delay]
    JL  .skip_move
    MOV WORD [ball_cnt], 0

    CALL erase_ball

    ; move ball
    MOV AX, [ballX]
    ADD AX, [ballDX]
    MOV [ballX], AX
    MOV AX, [ballY]
    ADD AX, [ballDY]
    MOV [ballY], AX

    ; left/right wall
    MOV AX, [ballX]
    CMP AX, PLAY_LEFT
    JLE .bx
    CMP AX, PLAY_RIGHT
    JLE .top
.bx:
    NEG WORD [ballDX]
    CALL beep_wall

.top:
    MOV AX, [ballY]
    CMP AX, PLAY_TOP
    JG  .paddle
    NEG WORD [ballDY]
    CALL beep_wall

.paddle:
    MOV AX, [ballY]
    CMP AX, PLAY_BOT - 1
    JNE .bottom
    MOV BX, [ballX]
    MOV CX, [paddleX]
    CMP BX, CX
    JL  .bottom
    ADD CX, PADLEN
    CMP BX, CX
    JGE .bottom
    NEG WORD [ballDY]
    CALL beep_wall
    JMP .bricks

.bottom:
    MOV AX, [ballY]
    CMP AX, PLAY_BOT
    JL  .bricks
    CALL beep_life
    DEC WORD [lives]
    MOV AX, [lives]
    CMP AX, 0
    JLE game_over
    ; respawn ball from paddle center
    MOV AX, [paddleX]
    ADD AX, 3           ; center of paddle (PADLEN/2)
    MOV [ballX], AX
    MOV WORD [ballY], PLAY_BOT - 2
    MOV WORD [ballDX], 1
    MOV WORD [ballDY], -1
    MOV WORD [ball_cnt], 0

.bricks:
    CALL check_brick_hit
    CALL check_all_clear
    CMP AX, 1
    JE  level_win
    CALL draw_ball

.skip_move:
    CALL draw_hud
    JMP game_loop

level_win:
    INC WORD [cur_level]
    MOV AX, [cur_level]
    CMP AX, 4
    JG  you_win
    ; speed up (reduce ball_delay per level, min 1)
    MOV AX, [ball_delay]
    CMP AX, 1
    JLE .ok
    DEC WORD [ball_delay]
.ok:
    MOV WORD [ball_cnt], 0
    ; also shrink frame delay slightly
    MOV AX, [spd]
    SUB AX, 1000h
    CMP AX, 2000h
    JGE .ok2
    MOV AX, 2000h
.ok2:
    MOV [spd], AX
    MOV WORD [paddleX], 37
    MOV WORD [ballX],   40
    MOV WORD [ballY],   14
    MOV WORD [ballDX],  1
    MOV WORD [ballDY], -1
    JMP level_start

you_win:
    CALL clear_screen
    MOV DH, 10
    MOV DL, 25
    CALL set_cursor
    MOV SI, msg_win
    CALL print_str
    CALL save_score
    MOV AH, 00h
    INT 16h
    JMP main_loop

game_over:
    CALL clear_screen
    MOV DH, 10
    MOV DL, 24
    CALL set_cursor
    MOV SI, msg_over
    CALL print_str
    MOV DH, 12
    MOV DL, 28
    CALL set_cursor
    MOV SI, msg_score_lbl
    CALL print_str
    MOV AX, [score]
    CALL print_num
    CALL save_score
    MOV AH, 00h
    INT 16h
    JMP main_loop

done:
    MOV AH, 01h
    MOV CX, 0607h
    INT 10h
    MOV AX, 4C00h
    INT 21h

; ============================================================
;  PROCEDURES
; ============================================================

; --- set_cursor: DH=row DL=col ---
set_cursor:
    MOV AH, 02h
    MOV BH, 00h
    INT 10h
    RET

; --- write_char: AL=char BL=color DH=row DL=col ---
; FIXED: pushes and restores CX so callers' loop counters survive
write_char:
    PUSH CX
    PUSH AX
    CALL set_cursor
    POP  AX
    MOV  AH, 09h
    MOV  BH, 00h
    MOV  CX, 01h
    INT  10h
    POP  CX
    RET

; --- clear_screen ---
clear_screen:
    MOV AH, 06h
    MOV AL, 00h
    MOV BH, 07h
    MOV CX, 0000h
    MOV DX, 184Fh
    INT 10h
    RET

; --- draw_border ---
draw_border:
    PUSH CX
    MOV CX, PLAY_LEFT
.tb:
    MOV DH, PLAY_TOP - 1
    MOV DL, CL
    MOV AL, '-'
    MOV BL, 0Bh
    CALL write_char
    MOV DH, PLAY_BOT
    CALL write_char
    INC CX
    CMP CX, PLAY_RIGHT
    JLE .tb
    MOV CX, PLAY_TOP
.sd:
    MOV DH, CL
    MOV DL, PLAY_LEFT - 1
    MOV AL, '|'
    MOV BL, 0Bh
    CALL write_char
    MOV DL, PLAY_RIGHT + 1
    CALL write_char
    INC CX
    CMP CX, PLAY_BOT
    JLE .sd
    POP CX
    RET

; --- reset_bricks ---
reset_bricks:
    PUSH CX
    MOV SI, 0
    MOV CX, BROWS * BCOLS
.lp:
    MOV BYTE [bricks + SI], 1
    INC SI
    LOOP .lp
    POP CX
    RET

; brick colors and scores by row
brick_colors: DB 0Ch, 0Eh, 0Ah, 0Bh
brick_pts:    DW  30,  20,  15,  10

; --- draw_bricks ---
; FIXED: uses DI as row index for color lookup so BX (row counter) stays intact
draw_bricks:
    PUSH BX
    PUSH CX
    XOR  SI, SI
    XOR  BX, BX          ; row counter
.row:
    CMP BX, BROWS
    JGE .done
    XOR CX, CX            ; col counter
.col:
    CMP CX, BCOLS
    JGE .nr
    MOV AL, [bricks + SI]
    CMP AL, 0
    JE  .skip

    PUSH BX               ; save row counter
    PUSH CX               ; save col counter

    MOV DI, BX            ; DI = row index (safe, BX preserved on stack)
    MOV BL, [brick_colors + DI]   ; BL = color for this row

    ; screen row = row + BROW1
    MOV AX, DI
    ADD AX, BROW1
    MOV DH, AL

    ; screen col = col*5 + BSCOL  (use DI for col)
    POP  CX               ; restore col counter
    PUSH CX               ; save again for outer restore
    MOV  AX, CX
    IMUL AX, AX, 5
    ADD  AX, BSCOL
    MOV  DL, AL

    MOV AL, 0DBh
    CALL write_char
    INC  DL
    CALL write_char
    INC  DL
    CALL write_char

    POP CX                ; restore col counter
    POP BX                ; restore row counter

.skip:
    INC SI
    INC CX
    JMP .col
.nr:
    INC BX
    JMP .row
.done:
    POP CX
    POP BX
    RET

; --- draw_paddle ---
draw_paddle:
    PUSH CX
    XOR CX, CX
.lp:
    CMP CX, PADLEN
    JGE .done
    MOV DH, PLAY_BOT - 1
    MOV AX, [paddleX]
    ADD AX, CX
    MOV DL, AL
    MOV AL, '='
    MOV BL, 09h
    CALL write_char
    INC CX
    JMP .lp
.done:
    POP CX
    RET

; --- erase_paddle ---
erase_paddle:
    PUSH CX
    XOR CX, CX
.lp:
    CMP CX, PADLEN
    JGE .done
    MOV DH, PLAY_BOT - 1
    MOV AX, [paddleX]
    ADD AX, CX
    MOV DL, AL
    MOV AL, ' '
    MOV BL, 07h
    CALL write_char
    INC CX
    JMP .lp
.done:
    POP CX
    RET

; --- draw_ball ---
draw_ball:
    MOV DH, [ballY]
    MOV DL, [ballX]
    MOV AL, 'O'
    MOV BL, 0Eh
    CALL write_char
    RET

; --- erase_ball ---
erase_ball:
    MOV DH, [ballY]
    MOV DL, [ballX]
    MOV AL, ' '
    MOV BL, 07h
    CALL write_char
    RET

; --- draw_hud: row 0=lives icons, row 1=score/level ---
draw_hud:
    ; row 0: life icons
    PUSH CX
    MOV DH, 0
    MOV DL, 2
    CALL set_cursor
    MOV SI, msg_life_lbl
    CALL print_str
    MOV CX, [lives]
    CMP CX, 0
    JLE .no_lives
.life_loop:
    MOV AL, 'O'
    MOV AH, 0Eh
    MOV BL, 0Ch    ; red
    INT 10h
    MOV AL, ' '
    MOV AH, 0Eh
    INT 10h
    LOOP .life_loop
    ; clear extra (in case lives dropped)
    MOV CX, 3
    MOV AX, [lives]
    SUB CX, AX
    CMP CX, 0
    JLE .no_lives
.clear_loop:
    MOV AL, ' '
    MOV AH, 0Eh
    INT 10h
    MOV AL, ' '
    MOV AH, 0Eh
    INT 10h
    LOOP .clear_loop
.no_lives:
    POP CX
    ; row 1: score and level
    MOV DH, 1
    MOV DL, 2
    CALL set_cursor
    MOV SI, msg_score_lbl
    CALL print_str
    MOV AX, [score]
    CALL print_num
    MOV SI, msg_level_lbl
    CALL print_str
    MOV AX, [cur_level]
    CALL print_num
    MOV AL, ' '
    MOV AH, 0Eh
    INT 10h
    RET

; --- print_str: SI = '$'-terminated string ---
print_str:
    PUSH AX
.lp:
    MOV AL, [SI]
    CMP AL, '$'
    JE  .done
    MOV AH, 0Eh
    INT 10h
    INC SI
    JMP .lp
.done:
    POP AX
    RET

; --- print_num: AX = number ---
print_num:
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  BX, 10
    XOR  CX, CX
.div:
    XOR  DX, DX
    DIV  BX
    PUSH DX
    INC  CX
    CMP  AX, 0
    JNE  .div
.prn:
    POP  DX
    ADD  DL, '0'
    MOV  AH, 0Eh
    MOV  AL, DL
    INT  10h
    LOOP .prn
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

; --- check_brick_hit ---
; FIXED: pushes BX/CX around the beep call so loop counters survive
check_brick_hit:
    PUSH BX
    PUSH CX
    XOR SI, SI
    XOR BX, BX
.row:
    CMP BX, BROWS
    JGE .done
    XOR CX, CX
.col:
    CMP CX, BCOLS
    JGE .nr
    MOV AL, [bricks + SI]
    CMP AL, 0
    JE  .skip
    ; brick screen row
    MOV AX, BX
    ADD AX, BROW1
    MOV [tmp_r], AX
    ; brick screen col
    MOV AX, CX
    IMUL AX, AX, 5
    ADD AX, BSCOL
    MOV [tmp_c], AX
    ; check ballY
    MOV DX, [ballY]
    CMP DX, [tmp_r]
    JNE .skip
    ; check ballX in range
    MOV DX, [ballX]
    CMP DX, [tmp_c]
    JL  .skip
    MOV AX, [tmp_c]
    ADD AX, 2
    CMP DX, AX
    JG  .skip
    ; hit!
    MOV BYTE [bricks + SI], 0
    ; erase brick cells
    MOV DH, [tmp_r]
    MOV DL, [tmp_c]
    MOV AL, ' '
    MOV BL, 07h
    CALL write_char
    INC DL
    CALL write_char
    INC DL
    CALL write_char
    ; add row-based score
    PUSH BX
    PUSH CX
    MOV  AX, BX
    SHL  AX, 1
    MOV  BX, brick_pts
    ADD  BX, AX
    MOV  AX, [BX]
    ADD  [score], AX
    POP  CX
    POP  BX
    NEG WORD [ballDY]
    PUSH BX
    PUSH CX
    CALL beep_brick
    POP  CX
    POP  BX
.skip:
    INC SI
    INC CX
    JMP .col
.nr:
    INC BX
    JMP .row
.done:
    POP CX
    POP BX
    RET

; --- check_all_clear: returns AX=1 if all bricks gone ---
check_all_clear:
    PUSH CX
    XOR SI, SI
    MOV CX, BROWS * BCOLS
.lp:
    MOV AL, [bricks + SI]
    CMP AL, 1
    JE  .no
    INC SI
    LOOP .lp
    MOV AX, 1
    POP CX
    RET
.no:
    MOV AX, 0
    POP CX
    RET

; --- PC speaker beeps ---
beep_wall:
    IN  AL, 61h
    OR  AL, 03h
    OUT 61h, AL
    PUSH CX
    MOV CX, 0800h
.d: LOOP .d
    POP CX
    IN  AL, 61h
    AND AL, 0FCh
    OUT 61h, AL
    RET

beep_brick:
    IN  AL, 61h
    OR  AL, 03h
    OUT 61h, AL
    PUSH CX
    MOV CX, 0E00h
.d: LOOP .d
    POP CX
    IN  AL, 61h
    AND AL, 0FCh
    OUT 61h, AL
    RET

beep_life:
    IN  AL, 61h
    OR  AL, 03h
    OUT 61h, AL
    PUSH CX
    MOV CX, 3000h
.d: LOOP .d
    POP CX
    IN  AL, 61h
    AND AL, 0FCh
    OUT 61h, AL
    RET

; --- save high score via DOS INT 21h ---
save_score:
    MOV AH, 3Ch
    MOV CX, 00h
    MOV DX, score_file
    INT 21h
    JC  .skip
    MOV [file_handle], AX
    MOV AX, [score]
    CALL num_to_buf
    MOV AH, 40h
    MOV BX, [file_handle]
    MOV CX, [buf_len]
    MOV DX, num_buf
    INT 21h
    MOV AH, 3Eh
    MOV BX, [file_handle]
    INT 21h
.skip:
    RET

num_to_buf:
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    MOV  BX, 10
    XOR  CX, CX
    MOV  DI, num_buf + 9
    MOV  BYTE [DI + 1], 0Ah
.d:
    XOR  DX, DX
    DIV  BX
    ADD  DL, '0'
    MOV  [DI], DL
    DEC  DI
    INC  CX
    CMP  AX, 0
    JNE  .d
    INC  DI
    INC  CX
    MOV  [buf_len], CX
    POP  DX
    POP  CX
    POP  BX
    POP  AX
    RET

; --- welcome screen ---
; FIXED: sets AH=09h before every INT 10h write-char call
show_welcome:
    CALL clear_screen
    MOV  DH, 5
    MOV  DL, 23
    CALL set_cursor
    MOV  SI, msg_title
    CALL print_str

    ; row 0 bricks - Red 0Ch
    MOV DH, 8
    MOV DL, 20
    CALL set_cursor
    MOV AH, 09h
    MOV AL, 0DBh
    MOV BL, 0Ch
    MOV BH, 00h
    MOV CX, 05h
    INT 10h

    ; row 1 bricks - Yellow 0Eh
    MOV DH, 9
    MOV DL, 20
    CALL set_cursor
    MOV AH, 09h
    MOV AL, 0DBh
    MOV BL, 0Eh
    MOV BH, 00h
    MOV CX, 05h
    INT 10h

    ; row 2 bricks - Green 0Ah
    MOV DH, 10
    MOV DL, 20
    CALL set_cursor
    MOV AH, 09h
    MOV AL, 0DBh
    MOV BL, 0Ah
    MOV BH, 00h
    MOV CX, 05h
    INT 10h

    ; row 3 bricks - Cyan 0Bh
    MOV DH, 11
    MOV DL, 20
    CALL set_cursor
    MOV AH, 09h
    MOV AL, 0DBh
    MOV BL, 0Bh
    MOV BH, 00h
    MOV CX, 05h
    INT 10h

    ; score labels next to bricks
    MOV DH, 8
    MOV DL, 26
    CALL set_cursor
    MOV SI, msg_pts_r0
    CALL print_str

    MOV DH, 9
    MOV DL, 26
    CALL set_cursor
    MOV SI, msg_pts_r1
    CALL print_str

    MOV DH, 10
    MOV DL, 26
    CALL set_cursor
    MOV SI, msg_pts_r2
    CALL print_str

    MOV DH, 11
    MOV DL, 26
    CALL set_cursor
    MOV SI, msg_pts_r3
    CALL print_str

    MOV DH, 15
    MOV DL, 15
    CALL set_cursor
    MOV SI, msg_rules
    CALL print_str

    MOV DH, 17
    MOV DL, 18
    CALL set_cursor
    MOV SI, msg_start
    CALL print_str
    RET

; ============================================================
;  DATA
; ============================================================
section .data

ballX       DW 40
ballY       DW 14
ballDX      DW 1
ballDY      DW -1
paddleX     DW 37
lives       DW 3
score       DW 0
cur_level   DW 1
spd         DW 0E000h    ; frame delay (higher = slower)
ball_cnt    DW 0          ; frame counter
ball_delay  DW 4          ; ball moves every N frames
tmp_r       DW 0
tmp_c       DW 0
file_handle DW 0
buf_len     DW 0

bricks      TIMES BROWS * BCOLS DB 1
num_buf     TIMES 12 DB 0

score_file  DB 'HISCORE.TXT', 0

msg_title    DB 'ATARI BREAKOUT - 3 Levels$'
msg_score_lbl DB 'Score:$'
msg_life_lbl  DB 'Lives: $'
msg_level_lbl DB '  Lvl:$'
msg_rules    DB 'Left/Right Arrows or A/D = Move Paddle$'
msg_start    DB 'ENTER = Start    ESC = Quit$'
msg_over     DB 'GAME OVER! Score saved to HISCORE.TXT$'
msg_win      DB 'YOU WIN! All levels cleared!$'
msg_pts_r0   DB ' = 30 pts (Red)$'
msg_pts_r1   DB ' = 20 pts (Yellow)$'
msg_pts_r2   DB ' = 15 pts (Green)$'
msg_pts_r3   DB ' = 10 pts (Cyan)$'

; session:13d209fc
