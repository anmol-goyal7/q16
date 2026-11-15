;=====================================================================
; mul16.asm  -  16-bit x 16-bit unsigned multiplication by SHIFT-AND-ADD
;               (the MUL / IMUL instructions are not used anywhere)
;
; COA Lab Problem 15: Multiply two 16-bit numbers using the shift-and-add
;                     method instead of using the native MUL instruction.
;
; Assembler : NASM, 32-bit Linux (system calls through int 0x80)
; Online    : paste this whole file into https://onecompiler.com/assembly
;             and press Run.
; Locally   : nasm -f elf32 mul16.asm -o mul16.o
;             ld -m elf_i386 mul16.o -o mul16
;             ./mul16
;
; Algorithm (n = 16):
;     M = multiplicand (widened to 32 bits), Q = multiplier,
;     P = 0 (32 bits), Count = 16
;     repeat until Count = 0:
;         if Q0 = 1 then P = P + M      ; 32-bit add = ADD low + ADC high
;         shift M left by 1             ; 32-bit shift = SHL low + RCL high
;         shift Q right by 1 (logical)  ; SHR
;         Count = Count - 1
;     P is the product. It always fits in 32 bits, because the largest
;     possible product is FFFFH x FFFFH = FFFE0001H < 2^32, so it can
;     never overflow.
;
; Register map of the algorithm (16-bit registers only):
;     SI = M low word         BX = M high word      (M is in BX:SI)
;     DI = Q (multiplier)     CX = Count
;     AX = P low word         DX = P high word      (P is in DX:AX)
; 32-bit registers appear only inside the print / system-call helpers
; at the end of the file, and every helper preserves the six registers
; above, so the algorithm never sees them change.
;=====================================================================

section .data
    ;------------------------------------------------------------------
    ; INPUTS: change the two numbers here (hex with an h suffix).
    ; A value that starts with A-F needs a leading 0, e.g. 0FFFFh.
    ;------------------------------------------------------------------
    num1        dw 1234h            ; multiplicand M
    num2        dw 5678h            ; multiplier   Q

    ; text printed by the helpers
    msg_title   db "Shift-and-Add Multiplication (no MUL)", 10
    len_title   equ $ - msg_title
    msg_mcand   db "Multiplicand : "
    len_mcand   equ $ - msg_mcand
    msg_mplier  db "Multiplier   : "
    len_mplier  equ $ - msg_mplier
    msg_head    db "Step | Q0 | Action | Partial Product", 10
    len_head    equ $ - msg_head
    msg_prod    db "Product      : "
    len_prod    equ $ - msg_prod
    msg_hopen   db "H ("                ; between the hex and decimal forms
    len_hopen   equ $ - msg_hopen
    msg_close   db ")", 10
    len_close   equ $ - msg_close
    msg_bar     db "   | "              ; after the step number
    len_bar     equ $ - msg_bar
    msg_add     db "  | ADD M  | "       ; after Q0 when Q0 = 1
    len_add     equ $ - msg_add
    msg_skip    db "  | SKIP   | "       ; after Q0 when Q0 = 0
    len_skip    equ $ - msg_skip
    msg_hnl     db "H", 10
    len_hnl     equ $ - msg_hnl
    hexdigits   db "0123456789ABCDEF"

section .bss
    numbuf      resb 12                 ; decimal digits are built here
    hexbuf      resb 8                  ; hex digits are built here
    save_lo     resw 1                  ; helper scratch: P low word
    save_hi     resw 1                  ; helper scratch: P high word
    save_q      resw 1                  ; helper scratch: Q
    save_e      resd 1                  ; helper scratch: a 32-bit value

section .text
    global _start

;=====================================================================
; MAIN PROGRAM: the shift-and-add algorithm
;=====================================================================
_start:
    ;--- print the title, both inputs and the table heading ----------
    call    print_banner

    ;--- Step 1: initialise ------------------------------------------
    mov     si, [num1]          ; SI = M low word = multiplicand
    xor     bx, bx              ; BX = M high word = 0 (M widened to 32 bits)
    mov     di, [num2]          ; DI = Q = multiplier
    xor     ax, ax              ; AX = P low word  = 0
    xor     dx, dx              ; DX = P high word = 0
    mov     cx, 16              ; CX = Count = n = 16 bits

next_bit:
    ;--- Step 2: test Q0, the lowest bit of the multiplier ------------
    test    di, 1               ; ZF = 1 when Q0 = 0
    jz      skip_add            ; Q0 = 0: no add this cycle

    ;--- Step 3: Q0 = 1, so P = P + M (32-bit add on 16-bit halves) --
    add     ax, si              ; P low  = P low  + M low, carry out -> CF
    adc     dx, bx              ; P high = P high + M high + CF

skip_add:
    ;--- print this step: number, Q0, ADD M / SKIP, partial product ---
    call    print_step

    ;--- Step 4: shift M left by 1 (32-bit shift on 16-bit halves) ---
    shl     si, 1               ; M low << 1, its top bit -> CF
    rcl     bx, 1               ; M high << 1, CF -> bit 0 of M high

    ;--- Step 5: shift Q right by 1 so the next bit becomes Q0 -------
    shr     di, 1               ; logical shift: a 0 enters at the top

    ;--- Step 6: Count = Count - 1, repeat until Count = 0 -----------
    dec     cx
    jnz     next_bit

    ;--- Step 7: DX:AX now holds the 32-bit product -------------------
    call    print_product
    call    exit_program


;=====================================================================
; HELPERS (printing and system calls). These are the only places that
; use 32-bit registers. Each public helper saves and restores the six
; 16-bit registers of the algorithm with push/pop. (32-bit values are
; parked in memory rather than pushed, so the file also assembles as
; 64-bit code if an online compiler uses nasm -f elf64.)
;=====================================================================

;---------------------------------------------------------------------
; print_banner: title, "Multiplicand : 1234H (4660)",
;               "Multiplier   : 5678H (22136)" and the table heading.
;---------------------------------------------------------------------
print_banner:
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di
    mov     ecx, msg_title
    mov     edx, len_title
    call    write
    mov     ecx, msg_mcand
    mov     edx, len_mcand
    call    write
    movzx   eax, word [num1]
    call    put_value16
    mov     ecx, msg_mplier
    mov     edx, len_mplier
    call    write
    movzx   eax, word [num2]
    call    put_value16
    mov     ecx, msg_head
    mov     edx, len_head
    call    write
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

;---------------------------------------------------------------------
; print_step: one table line, e.g. " 4   | 1  | ADD M  | 000091A0H"
;   in: CX = Count before it is decremented (16..1), so step = 17 - CX
;       DI = Q (bit 0 is the Q0 tested this cycle)
;       DX:AX = partial product P after this cycle's add
;---------------------------------------------------------------------
print_step:
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di
    mov     [save_lo], ax       ; keep P and Q, the syscalls clobber registers
    mov     [save_hi], dx
    mov     [save_q], di
    ; step number, right-aligned in 2 columns
    movzx   eax, cx
    neg     eax
    add     eax, 17             ; EAX = 17 - Count = step number
    cmp     eax, 10
    jae     .two_digits
    mov     [save_e], eax
    mov     ecx, msg_bar        ; a leading space (first byte of "   | ")
    mov     edx, 1
    call    write
    mov     eax, [save_e]
.two_digits:
    call    put_dec
    mov     ecx, msg_bar
    mov     edx, len_bar
    call    write
    ; Q0 as '0' or '1', then the action
    movzx   eax, word [save_q]
    and     eax, 1
    mov     [save_e], eax
    call    put_dec
    mov     eax, [save_e]
    mov     ecx, msg_skip
    mov     edx, len_skip
    test    eax, eax
    jz      .action
    mov     ecx, msg_add
    mov     edx, len_add
.action:
    call    write
    ; partial product as 8 hex digits
    movzx   eax, word [save_hi]
    shl     eax, 16
    mov     ax, [save_lo]       ; EAX = P = DX:AX
    mov     ecx, 8
    call    put_hex
    mov     ecx, msg_hnl
    mov     edx, len_hnl
    call    write
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
    ret

;---------------------------------------------------------------------
; print_product: "Product      : 06260060H (103153760)"
;   in: DX:AX = product
;---------------------------------------------------------------------
print_product:
    push    ax
    push    bx
    push    cx
    push    dx
    push    si
    push    di
    mov     [save_lo], ax
    mov     [save_hi], dx
    mov     ecx, msg_prod
    mov     edx, len_prod
    call    write
    movzx   eax, word [save_hi]
    shl     eax, 16
    mov     ax, [save_lo]       ; EAX = DX:AX as one 32-bit value
    mov     [save_e], eax
    mov     ecx, 8
    call    put_hex
    mov     ecx, msg_hopen
    mov     edx, len_hopen
    call    write
    mov     eax, [save_e]
    call    put_dec
    mov     ecx, msg_close
    mov     edx, len_close
    call    write
    pop     di
    pop     si
    pop     dx
    pop     cx
    pop     bx
    pop     ax
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

; put_value16: "XXXXH (decimal)\n" for the 16-bit value in EAX
put_value16:
    mov     [save_e], eax
    mov     ecx, 4
    call    put_hex
    mov     ecx, msg_hopen
    mov     edx, len_hopen
    call    write
    mov     eax, [save_e]
    call    put_dec
    mov     ecx, msg_close
    mov     edx, len_close
    call    write
    ret

; put_hex: print the low ECX hex digits of EAX (no MUL: shifts and a table)
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

; put_dec: print EAX as an unsigned decimal number (no MUL: uses DIV by 10)
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
