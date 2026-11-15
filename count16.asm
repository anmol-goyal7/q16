;=====================================================================
; count16.asm  -  count the 1 bits and the 0 bits of the AX register
;                 by the SHIFT-AND-COUNT method
;
; COA Lab Problem 16: Count the total number of set bits (1s) and
;                     cleared bits (0s) within the AX register.
;
; Assembler : NASM, 32-bit Linux (system calls through int 0x80)
; Online    : paste this whole file into https://onecompiler.com/assembly
;             and press Run.
; Locally   : nasm -f elf32 count16.asm -o count16.o
;             ld -m elf_i386 count16.o -o count16
;             ./count16
;
; Algorithm:
;     AX = the 16-bit value, ONES = 0, ZEROS = 0, Count = 16
;     repeat until Count = 0:
;         shift AX right by 1 (logical) ; SHR: the bit shifted out -> CF
;         if CF = 1 then ONES  = ONES  + 1
;                   else ZEROS = ZEROS + 1
;         Count = Count - 1
;     ONES + ZEROS = 16 always, because every cycle counts exactly one bit.
;     The shifting destroys AX (it ends as 0000H), so the original value
;     is saved on the stack first (PUSH AX) and restored at the end (POP AX).
;
; Register map of the algorithm (16-bit and 8-bit registers only):
;     AX = the value being shifted        CX = Count
;     BL = ONES  (number of 1 bits)       BH = ZEROS (number of 0 bits)
; 32-bit registers appear only inside the print / system-call helpers
; at the end of the file, and every helper preserves AX, BX and CX,
; so the algorithm never sees them change.
;=====================================================================

section .data
    ;------------------------------------------------------------------
    ; INPUT: change the number here (hex with an h suffix).
    ; A value that starts with A-F needs a leading 0, e.g. 0FFFFh.
    ;------------------------------------------------------------------
    num         dw 1234h            ; the value loaded into AX

    ; text printed by the helpers
    msg_title   db "Count 1s and 0s in AX", 10
    len_title   equ $ - msg_title
    msg_ax      db "AX    : "
    len_ax      equ $ - msg_ax
    msg_hopen   db "H ("                ; between the hex and binary forms
    len_hopen   equ $ - msg_hopen
    msg_bclose  db "b)", 10
    len_bclose  equ $ - msg_bclose
    msg_head    db "Step | CF | Action", 10
    len_head    equ $ - msg_head
    msg_bar     db "   | "              ; after the step number
    len_bar     equ $ - msg_bar
    msg_one     db "  | ONES++", 10     ; after CF when CF = 1
    len_one     equ $ - msg_one
    msg_zero    db "  | ZEROS++", 10    ; after CF when CF = 0
    len_zero    equ $ - msg_zero
    msg_ones    db "Ones  : "
    len_ones    equ $ - msg_ones
    msg_zeros   db "Zeros : "
    len_zeros   equ $ - msg_zeros
    msg_nl      db 10
    hexdigits   db "0123456789ABCDEF"

section .bss
    numbuf      resb 12                 ; decimal digits are built here
    hexbuf      resb 8                  ; hex digits are built here
    binbuf      resb 16                 ; binary digits are built here
    save_cnt    resw 1                  ; helper scratch: BX (ZEROS:ONES)
    save_e      resd 1                  ; helper scratch: a 32-bit value

section .text
    global _start

;=====================================================================
; MAIN PROGRAM: the shift-and-count algorithm
;=====================================================================
_start:
    ;--- print the title, the input and the table heading -------------
    call    print_banner

    ;--- Step 1: load the value and save a copy -----------------------
    mov     ax, [num]           ; AX = the value to examine
    push    ax                  ; save the original AX (shifting destroys it)

    ;--- Step 2: initialise the counters ------------------------------
    xor     bl, bl              ; BL = ONES  = 0
    xor     bh, bh              ; BH = ZEROS = 0
    mov     cx, 16              ; CX = Count = 16 bits

next_bit:
    ;--- Step 3: shift AX right by 1, the lowest bit drops into CF ----
    shr     ax, 1               ; logical shift: 0 enters at the top
    jnc     bit_zero            ; CF = 0: the bit was a 0

    ;--- Step 4a: CF = 1, so count a one ------------------------------
    inc     bl                  ; ONES = ONES + 1   (INC leaves CF alone)
    jmp     counted

bit_zero:
    ;--- Step 4b: CF = 0, so count a zero -----------------------------
    inc     bh                  ; ZEROS = ZEROS + 1 (INC leaves CF alone)

counted:
    ;--- print this step: number, CF, ONES++ / ZEROS++ ----------------
    call    print_step

    ;--- Step 5: Count = Count - 1, repeat until Count = 0 ------------
    loop    next_bit            ; CX = CX - 1, jump if CX is not 0

    ;--- Step 6: AX is now 0000H, so restore the saved original -------
    pop     ax                  ; AX = original value again

    ;--- Step 7: BL = number of 1s, BH = number of 0s -----------------
    call    print_result
    call    exit_program


;=====================================================================
; HELPERS (printing and system calls). These are the only places that
; use 32-bit registers. Each public helper saves and restores AX, BX
; and CX with push/pop. (32-bit values are parked in memory rather than
; pushed, so the file also assembles as 64-bit code if an online
; compiler uses nasm -f elf64.)
;
; On a real 8086 LOOP counts with CX. In this 32-bit build the same
; instruction counts with the whole of ECX, so every public helper ends
; with "movzx ecx, cx", which keeps the upper half of ECX at zero and
; makes ECX equal to CX.
;=====================================================================

;---------------------------------------------------------------------
; print_banner: title, "AX    : 1234H (0001001000110100b)" and the
;               table heading.
;---------------------------------------------------------------------
print_banner:
    push    ax
    push    bx
    push    cx
    mov     ecx, msg_title
    mov     edx, len_title
    call    write
    mov     ecx, msg_ax
    mov     edx, len_ax
    call    write
    movzx   eax, word [num]
    mov     ecx, 4
    call    put_hex             ; the value as 4 hex digits
    mov     ecx, msg_hopen
    mov     edx, len_hopen
    call    write
    movzx   eax, word [num]
    call    put_bin16           ; the value as 16 binary digits
    mov     ecx, msg_bclose
    mov     edx, len_bclose
    call    write
    mov     ecx, msg_head
    mov     edx, len_head
    call    write
    pop     cx
    pop     bx
    pop     ax
    movzx   ecx, cx             ; ECX = CX (see the note above)
    ret

;---------------------------------------------------------------------
; print_step: one table line, e.g. " 3   | 1  | ONES++"
;   in: CF = the bit that SHR just shifted out (CALL, PUSH, MOV, INC
;            and JMP do not change CF, so it is still valid here)
;       CX = Count before it is decremented (16..1), so step = 17 - CX
;---------------------------------------------------------------------
print_step:
    push    ax
    push    bx
    push    cx
    mov     dword [save_e], 0   ; remember CF as 0 or 1 (MOV keeps flags)
    jnc     .cf_saved
    mov     dword [save_e], 1
.cf_saved:
    ; step number, right-aligned in 2 columns
    movzx   eax, cx
    neg     eax
    add     eax, 17             ; EAX = 17 - Count = step number
    cmp     eax, 10
    jae     .two_digits
    push    ax                  ; keep the step number over the write
    mov     ecx, msg_bar        ; a leading space (first byte of "   | ")
    mov     edx, 1
    call    write
    pop     ax
    movzx   eax, ax
.two_digits:
    call    put_dec
    mov     ecx, msg_bar
    mov     edx, len_bar
    call    write
    ; CF as '0' or '1', then the action
    mov     eax, [save_e]
    call    put_dec
    mov     ecx, msg_zero
    mov     edx, len_zero
    cmp     dword [save_e], 0
    je      .action
    mov     ecx, msg_one
    mov     edx, len_one
.action:
    call    write
    pop     cx
    pop     bx
    pop     ax
    movzx   ecx, cx             ; ECX = CX (see the note above)
    ret

;---------------------------------------------------------------------
; print_result: "Ones  : 5" and "Zeros : 11"
;   in: BL = ONES, BH = ZEROS
;---------------------------------------------------------------------
print_result:
    push    ax
    push    bx
    push    cx
    mov     [save_cnt], bx      ; the syscalls clobber BX
    mov     ecx, msg_ones
    mov     edx, len_ones
    call    write
    movzx   eax, byte [save_cnt]        ; low byte = BL = ONES
    call    put_dec
    mov     ecx, msg_nl
    mov     edx, 1
    call    write
    mov     ecx, msg_zeros
    mov     edx, len_zeros
    call    write
    movzx   eax, byte [save_cnt + 1]    ; high byte = BH = ZEROS
    call    put_dec
    mov     ecx, msg_nl
    mov     edx, 1
    call    write
    pop     cx
    pop     bx
    pop     ax
    movzx   ecx, cx             ; ECX = CX (see the note above)
    ret

;---------------------------------------------------------------------
; exit_program: sys_exit(0)
;---------------------------------------------------------------------
exit_program:
    mov     eax, 1              ; sys_exit
    xor     ebx, ebx            ; exit code 0
    int     0x80

;---------------------------------------------------------------------
; Low-level helpers below may change any register; only the public
; helpers above call them.
;---------------------------------------------------------------------

; put_hex: print the low ECX hex digits of EAX (shifts and a table)
put_hex:
    mov     edi, ecx            ; EDI = number of digits
.digit:
    mov     edx, eax
    and     edx, 0Fh            ; lowest nibble
    mov     dl, [hexdigits + edx]
    mov     [hexbuf + ecx - 1], dl   ; fill the buffer from the right
    shr     eax, 4
    dec     ecx
    jnz     .digit
    mov     ecx, hexbuf
    mov     edx, edi
    call    write
    ret

; put_bin16: print the low 16 bits of EAX as 16 binary digits
put_bin16:
    mov     ecx, 16
.bit:
    mov     dl, '0'
    shr     eax, 1              ; lowest bit -> CF
    adc     dl, 0               ; '0' + CF = '0' or '1'
    mov     [binbuf + ecx - 1], dl   ; fill the buffer from the right
    dec     ecx
    jnz     .bit
    mov     ecx, binbuf
    mov     edx, 16
    call    write
    ret

; put_dec: print EAX as an unsigned decimal number (DIV by 10)
put_dec:
    mov     edi, numbuf + 12    ; fill the buffer from the right
    mov     ebx, 10
.digit:
    xor     edx, edx
    div     ebx                 ; EAX = EAX / 10, EDX = remainder 0..9
    add     dl, '0'
    dec     edi
    mov     [edi], dl
    test    eax, eax
    jnz     .digit
    mov     ecx, edi            ; first digit
    mov     edx, numbuf + 12
    sub     edx, edi            ; number of digits
    call    write
    ret

; write: sys_write(stdout, ECX = address, EDX = length)
write:
    mov     eax, 4              ; sys_write
    mov     ebx, 1              ; file descriptor 1 = stdout
    int     0x80
    ret
