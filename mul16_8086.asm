;=====================================================================
; MUL16_8086.ASM - 16-bit x 16-bit unsigned multiplication by the
;                  SHIFT-AND-ADD method on the 8086 (no MUL / IMUL)
;
; COA Lab Problem 15: Multiply two 16-bit numbers using the shift-and-add
;                     method instead of using the native MUL instruction.
;
; Assembler : MASM / TASM (DOSBox) or emu8086
; emu8086   : File > Open this file, then Emulate > Run.
; DOSBox    : copy it as MUL16.ASM (DOS uses 8.3 file names), then
;               MASM MUL16.ASM;     LINK MUL16.OBJ;     MUL16
;             or TASM MUL16.ASM     TLINK MUL16.OBJ     MUL16
;
; Algorithm (n = 16):
;     M = multiplicand (widened to 32 bits in BX:SI), Q = multiplier (DI)
;     P = 0 (32 bits in DX:AX), Count = 16 (CX)
;     repeat until Count = 0:
;         if Q0 = 1 then P = P + M        (ADD low words, ADC high words)
;         shift M left 1                  (SHL low word, RCL high word)
;         shift Q right 1 (logical)       (SHR)
;         Count = Count - 1
;     The 32-bit product is stored in PROD_HI:PROD_LO and printed in hex.
;     It can never overflow: FFFFH x FFFFH = FFFE0001H fits in 32 bits.
;
; Expected output for the default inputs:
;     SHIFT-AND-ADD MULTIPLICATION (NO MUL)
;     MULTIPLICAND : 1234H
;     MULTIPLIER   : 5678H
;     PRODUCT      : 06260060H
;=====================================================================

.MODEL SMALL
.STACK 100H

.DATA
    NUM1    DW 1234H                ; multiplicand M  <-- change inputs here
    NUM2    DW 5678H                ; multiplier   Q  <-- change inputs here
    PROD_LO DW ?                    ; product, low word
    PROD_HI DW ?                    ; product, high word

    MSG1    DB 'SHIFT-AND-ADD MULTIPLICATION (NO MUL)', 0DH, 0AH, '$'
    MSG2    DB 'MULTIPLICAND : $'
    MSG3    DB 'H', 0DH, 0AH, 'MULTIPLIER   : $'
    MSG4    DB 'H', 0DH, 0AH, 'PRODUCT      : $'
    MSG5    DB 'H', 0DH, 0AH, '$'

.CODE
MAIN PROC
    ;--- initialise the data segment ---------------------------------
    MOV AX, @DATA
    MOV DS, AX

    ;--- print the title and both inputs -----------------------------
    LEA DX, MSG1
    MOV AH, 09H                     ; DOS: print '$'-terminated string
    INT 21H
    LEA DX, MSG2
    MOV AH, 09H
    INT 21H
    MOV BX, NUM1
    CALL PRINT_HEX16                ; multiplicand in hex
    LEA DX, MSG3
    MOV AH, 09H
    INT 21H
    MOV BX, NUM2
    CALL PRINT_HEX16                ; multiplier in hex

    ;--- Step 1: initialise the registers ----------------------------
    MOV SI, NUM1                    ; SI = M low word = multiplicand
    XOR BX, BX                      ; BX = M high word = 0
    MOV DI, NUM2                    ; DI = Q = multiplier
    XOR AX, AX                      ; AX = P low word  = 0
    XOR DX, DX                      ; DX = P high word = 0
    MOV CX, 16                      ; CX = Count = 16

NEXT_BIT:
    ;--- Step 2: test Q0, the lowest bit of the multiplier ------------
    TEST DI, 1                      ; ZF = 1 when Q0 = 0
    JZ SKIP_ADD                     ; Q0 = 0: no add this cycle

    ;--- Step 3: Q0 = 1, so P = P + M (32-bit add) -------------------
    ADD AX, SI                      ; low words, carry out -> CF
    ADC DX, BX                      ; high words + CF

SKIP_ADD:
    ;--- Step 4: shift M left by 1 (32-bit shift) --------------------
    SHL SI, 1                       ; low word, top bit -> CF
    RCL BX, 1                       ; high word, CF -> bit 0

    ;--- Step 5: shift Q right by 1 so the next bit becomes Q0 -------
    SHR DI, 1                       ; logical: 0 enters at the top

    ;--- Step 6: Count = Count - 1, repeat until Count = 0 -----------
    DEC CX
    JNZ NEXT_BIT

    ;--- Step 7: store the 32-bit product ----------------------------
    MOV PROD_LO, AX
    MOV PROD_HI, DX

    ;--- print the product as 8 hex digits ---------------------------
    LEA DX, MSG4
    MOV AH, 09H
    INT 21H
    MOV BX, PROD_HI
    CALL PRINT_HEX16                ; high word first
    MOV BX, PROD_LO
    CALL PRINT_HEX16                ; then low word
    LEA DX, MSG5
    MOV AH, 09H
    INT 21H

    ;--- return to DOS -----------------------------------------------
    MOV AH, 4CH
    INT 21H
MAIN ENDP

;---------------------------------------------------------------------
; PRINT_HEX16: print BX as 4 hex digits with INT 21H, AH = 02H.
; Rotates the top nibble into the bottom each time (no MUL needed).
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

END MAIN
