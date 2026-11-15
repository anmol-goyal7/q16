;=====================================================================
; COUNT16_8086.ASM - count the 1 bits and the 0 bits of the AX register
;                    by the SHIFT-AND-COUNT method on the 8086
;
; COA Lab Problem 16: Count the total number of set bits (1s) and
;                     cleared bits (0s) within the AX register.
;
; Assembler : MASM / TASM (DOSBox) or emu8086
; emu8086   : File > Open this file, then Emulate > Run.
; DOSBox    : copy it as COUNT16.ASM (DOS uses 8.3 file names), then
;               MASM COUNT16.ASM;   LINK COUNT16.OBJ;   COUNT16
;             or TASM COUNT16.ASM   TLINK COUNT16.OBJ   COUNT16
;
; Algorithm:
;     AX = the 16-bit value, ONES = 0 (BL), ZEROS = 0 (BH), Count = 16 (CX)
;     repeat until Count = 0:
;         shift AX right by 1 (logical)   (SHR: the bit shifted out -> CF)
;         if CF = 1 then ONES  = ONES  + 1   (JNC skips this, INC BL)
;                   else ZEROS = ZEROS + 1   (INC BH)
;         Count = Count - 1                  (LOOP)
;     ONES + ZEROS = 16 always. The shifting destroys AX, so the original
;     value is saved with PUSH AX and restored with POP AX.
;     The results are stored in the memory variables ONES and ZEROS and
;     printed in decimal.
;
; Expected output for the default input:
;     COUNT 1S AND 0S IN AX
;     AX    : 1234H
;     ONES  : 5
;     ZEROS : 11
;=====================================================================

.MODEL SMALL
.STACK 100H

.DATA
    NUM     DW 1234H                ; the value loaded into AX  <-- change it here
    ONES    DB 0                    ; result: number of 1 bits
    ZEROS   DB 0                    ; result: number of 0 bits

    MSG1    DB 'COUNT 1S AND 0S IN AX', 0DH, 0AH, '$'
    MSG2    DB 'AX    : $'
    MSG3    DB 'H', 0DH, 0AH, 'ONES  : $'
    MSG4    DB 0DH, 0AH, 'ZEROS : $'
    MSG5    DB 0DH, 0AH, '$'

.CODE
MAIN PROC
    ;--- initialise the data segment ---------------------------------
    MOV AX, @DATA
    MOV DS, AX

    ;--- print the title and the input -------------------------------
    LEA DX, MSG1
    MOV AH, 09H                     ; DOS: print '$'-terminated string
    INT 21H
    LEA DX, MSG2
    MOV AH, 09H
    INT 21H
    MOV BX, NUM
    CALL PRINT_HEX16                ; the value in hex

    ;--- Step 1: load the value and save a copy ----------------------
    MOV AX, NUM                     ; AX = the value to examine
    PUSH AX                         ; save the original AX (shifting destroys it)

    ;--- Step 2: initialise the counters -----------------------------
    XOR BL, BL                      ; BL = ONES  = 0
    XOR BH, BH                      ; BH = ZEROS = 0
    MOV CX, 16                      ; CX = Count = 16

NEXT_BIT:
    ;--- Step 3: shift AX right by 1, the lowest bit drops into CF ---
    SHR AX, 1                       ; logical: 0 enters at the top
    JNC BIT_ZERO                    ; CF = 0: the bit was a 0

    ;--- Step 4a: CF = 1, so count a one -----------------------------
    INC BL                          ; ONES = ONES + 1
    JMP COUNTED

BIT_ZERO:
    ;--- Step 4b: CF = 0, so count a zero ----------------------------
    INC BH                          ; ZEROS = ZEROS + 1

COUNTED:
    ;--- Step 5: Count = Count - 1, repeat until Count = 0 -----------
    LOOP NEXT_BIT                   ; CX = CX - 1, jump if CX is not 0

    ;--- Step 6: AX is now 0000H, so restore the saved original ------
    POP AX                          ; AX = original value again

    ;--- Step 7: store the results in memory -------------------------
    MOV ONES, BL
    MOV ZEROS, BH

    ;--- print both counts in decimal --------------------------------
    LEA DX, MSG3
    MOV AH, 09H
    INT 21H
    MOV AL, ONES
    CALL PRINT_DEC8                 ; number of 1 bits
    LEA DX, MSG4
    MOV AH, 09H
    INT 21H
    MOV AL, ZEROS
    CALL PRINT_DEC8                 ; number of 0 bits
    LEA DX, MSG5
    MOV AH, 09H
    INT 21H

    ;--- return to DOS -----------------------------------------------
    MOV AH, 4CH
    INT 21H
MAIN ENDP

;---------------------------------------------------------------------
; PRINT_HEX16: print BX as 4 hex digits with INT 21H, AH = 02H.
; Rotates the top nibble into the bottom each time.
; All registers are preserved.
;---------------------------------------------------------------------
PRINT_HEX16 PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    MOV CX, 4                       ; 4 hex digits
PH_NEXT:
    PUSH CX
    MOV CL, 4
    ROL BX, CL                      ; next nibble -> low 4 bits of BX
    POP CX
    MOV DL, BL
    AND DL, 0FH                     ; DL = 0..15
    CMP DL, 9
    JBE PH_DIGIT
    ADD DL, 7                       ; 10..15 -> 'A'..'F'
PH_DIGIT:
    ADD DL, '0'
    MOV AH, 02H                     ; DOS: print the character in DL
    INT 21H
    LOOP PH_NEXT
    POP DX
    POP CX
    POP BX
    POP AX
    RET
PRINT_HEX16 ENDP

;---------------------------------------------------------------------
; PRINT_DEC8: print AL (0..99) in decimal with INT 21H, AH = 02H.
; DIV by 10 gives the tens digit in AL and the units digit in AH.
; A leading zero is not printed. All registers are preserved.
;---------------------------------------------------------------------
PRINT_DEC8 PROC
    PUSH AX
    PUSH BX
    PUSH DX
    MOV AH, 0                       ; AX = the number
    MOV BL, 10
    DIV BL                          ; AL = tens, AH = units
    MOV BX, AX                      ; BL = tens, BH = units (INT 21H changes AL)
    CMP BL, 0
    JE PD_UNITS                     ; no tens digit for 0..9
    MOV DL, BL
    ADD DL, '0'
    MOV AH, 02H                     ; DOS: print the character in DL
    INT 21H
PD_UNITS:
    MOV DL, BH
    ADD DL, '0'
    MOV AH, 02H
    INT 21H
    POP DX
    POP BX
    POP AX
    RET
PRINT_DEC8 ENDP

END MAIN
