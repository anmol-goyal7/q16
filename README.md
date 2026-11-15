# 8086 Lab Project: Shift-and-Add Multiply (Q15) and Count 1s and 0s in AX (Q16)

Two COA lab problems, each with an interactive step-by-step visualizer and working **8086 assembly programs**:

| | Problem | Page | Programs |
|---|---|---|---|
| **Q15** | *"Multiply two 16-bit numbers using the shift-and-add method instead of using the native MUL instruction."* | `index.html` | `mul16.asm`, `mul16_8086.asm` |
| **Q16** | *"Count the total number of set bits (1s) and cleared bits (0s) within the AX register."* | `bitcount.html` | `count16.asm`, `count16_8086.asm` |

**Live demos:**

- Q15 Shift-and-Add Multiply: https://anmol-goyal7.github.io/shift-add-multiplier-visualizer/
- Q16 Count 1s and 0s in AX: https://anmol-goyal7.github.io/shift-add-multiplier-visualizer/bitcount.html

A nav bar at the top of each page switches between the two. A sibling project of the Booth's Multiplication Algorithm Visualizer.

## Features: Q15 Shift-and-Add Multiply (`index.html`)

- Unsigned inputs in **decimal or hex** (`1234`, `1234H`, `0x1234`) at 4, 8 or 16 bits, with inline range validation. Negative numbers are rejected with a pointer to Booth's algorithm.
- Binary setup: M and Q in binary, P sized at 2n bits, and a note proving the product can never overflow.
- Textbook step table: `Step | Q0 | Action | M | Q | P | Count`, two rows per cycle (*Add M* / *No add*, then *Shift M left, Q right*).
- Large register diagram of M, Q and P with Q₀ highlighted, changed bits flashing and a one-line reason for each step. 32-bit registers fit on a laptop and wrap per 16-bit word on a phone.
- **Long-multiplication view**: the paper method in binary, with M written once per multiplier bit, zero rows greyed out and a running sum, revealed in sync with the steps.
- Next / Previous / Play-Pause (1.2 s) / Run all / Reset, plus keyboard shortcuts (← → Space Home End).
- Result panel with the product in binary, hex and decimal, checked against BigInt multiplication outside the algorithm.
- Presets: 13 × 11, 15 × 15, 0 × 9, 1 × 255, 200 × 150, 1234H × 5678H (the assembly default) and FFFFH × FFFFH.
- "How it works" tab with an SVG flowchart, an "8086 Assembly" tab (highlighted source, copy button, real program output, instruction-to-step table) and a "Shift-add vs Booth's" tab.
- Responsive, light theme by default with a dark mode toggle.
- **Single file, fully offline:** no CDNs, no web fonts, all CSS/JS inline.

## Features: Q16 Count 1s and 0s in AX (`bitcount.html`)

The textbook **shift-and-count** method: AX = value, ONES = 0, ZEROS = 0, Count = 16. Each cycle shifts AX right by 1 (logical), so the bit shifted out lands in **CF**; CF = 1 gives ONES++, otherwise ZEROS++; then Count goes down by 1. It stops when Count = 0.

- One 16-bit input in **hex or decimal** (`1234`, `1234H`, `0x1234`, or `4660`), validated 0 to FFFFH with inline errors.
- Register view: **AX as 16 bit boxes**, the **CF** box next to it, and **ONES**, **ZEROS** and Count as big numbers. Each step animates the shift: the bits move right, the outgoing bit drops into CF and the matching counter ticks, with a one-line reason such as *"CF = 1, so ONES++"*.
- The **saved copy of AX** is shown throughout. The shifting destroys AX (it ends as 0000H), so the original is saved first, exactly as the assembly does with `PUSH AX` / `POP AX`.
- The invariant **ONES + ZEROS = bits examined so far** is shown at every step and reaches 16 at the end.
- Step table: `Step | AX (binary) | CF | Action | ONES | ZEROS | Count`, first row *Initial*, then one row per bit (*ONES++* / *ZEROS++*).
- The same controls as Q15: Next / Previous / Play-Pause (1.2 s) / Run all / Reset and the keyboard shortcuts (← → Space Home End).
- Result panel with ONES, ZEROS, the check `ONES + ZEROS = 16 ✓`, and an independent check computed outside the algorithm (counting the `1` characters of `value.toString(2)`).
- Presets: 0000H (all zeros), FFFFH (all ones), AAAAH (alternating), 8001H (edges only), 00FFH and 1234H (the assembly default).
- "How it works" tab with an SVG flowchart, an "8086 Assembly" tab (highlighted source, copy button, OneCompiler link, real program output, instruction-to-step table) and an "Other methods" tab (ROL, TEST with a mask, Kernighan's `x & (x − 1)`, and why shift-and-count is the textbook one).
- Same theme, dark mode (the choice is shared between the two pages) and footer as Q15. **Single file, fully offline.**

## Run it locally

No build step and no dependencies. Either:

- open `index.html` or `bitcount.html` directly in a browser (double-click it). Each page works on its own; keep both in the same folder so the nav links work, or
- serve the folder: `python3 -m http.server`, then visit http://localhost:8000 (Q15) or http://localhost:8000/bitcount.html (Q16)

## Run the tests

```sh
node test.js        # both websites' algorithms (any recent Node.js)
./test_asm.sh       # all the assembly programs (needs nasm, ld, python3, node)
```

`test.js` extracts the `<script id="shiftadd-core">` block from `index.html` and the `<script id="bitcount-core">` block from `bitcount.html` and runs each in a Node VM, so it tests the exact code the pages run.

**Q15 checks in `test.js`:**

- every (M, Q) pair at 4 bits (256) and 8 bits (65,536),
- 50,000 seeded random pairs plus every combination of extremes (0, 1, max − 1, max and all powers of 2) at 16 bits, against BigInt `a * b`,
- every row of every trace: an add happens exactly when Q0 = 1, P changes by exactly M or 0, M doubles, Q halves, Count goes down,
- the 13 × 11 hand-worked trace at 4 bits, row by row,
- input parsing and validation (decimal, hex, ranges, negatives, widths),
- that the programs shown on the 8086 tab are identical to `mul16.asm` and `mul16_8086.asm`.

**Q16 checks in `test.js`:**

- **all 65,536 values** of AX against an independent popcount,
- every row of every trace: CF equals the bit shifted out, exactly one counter changes per step, ONES + ZEROS equals the number of steps done, AX halves, Count goes down,
- the 1234H trace, row by row, against a hand-worked table,
- the presets, and input parsing and validation (hex, decimal, 0 to FFFFH, negatives),
- that the programs shown on the 8086 tab are identical to `count16.asm` and `count16_8086.asm`,
- that both pages carry the shared nav with the right page highlighted, and load nothing external.

**Q15 checks in `test_asm.sh`:** it substitutes each test case into a copy of `mul16.asm`, then assembles it (`nasm -f elf32`), links it (`ld -m elf_i386`), runs it and compares the whole output, including the parsed Product line, with python3. It checks:

- the cases 0×0, 0×1234H, 1×1, 1×FFFFH, FFFFH×FFFFH, 8000H×2, 00FFH×00FFH, 1234H×5678H and 000DH×000BH, plus 40 seeded random pairs,
- that neither `.asm` file contains a `MUL` or `IMUL` instruction (with a self-test of the detector),
- that the MASM program's algorithm block is identical, instruction for instruction, to the tested NASM one,
- that the website's trace matches the program's 16 partial products for 1234H × 5678H,
- that the output shown on the 8086 tab is a real run, and that the program also works as 64-bit code (`nasm -f elf64`).

**Q16 checks in `test_asm.sh`:** it substitutes each value into a copy of `count16.asm`, assembles, links and runs it, parses the `Ones` and `Zeros` lines and compares them (and the whole output) with python3. It checks:

- the values 0000, FFFF, AAAA, 5555, 8000, 0001, 8001, 00FF, FF00 and 1234 (hex), plus 40 seeded random values,
- that the algorithm really is `SHR AX,1` + `JNC` + `INC BL` / `INC BH` + `LOOP`, with `PUSH AX` / `POP AX` around it,
- that the MASM program's algorithm block is identical, instruction for instruction, to the tested NASM one,
- that the website's CF sequence matches the program's 16 step lines for 1234H,
- that the output shown on the 8086 tab is a real run, and that the program also works as 64-bit code.

## Assembly programs: Q15

Neither program uses `MUL` or `IMUL` anywhere. Decimal printing uses `DIV` by 10.

| File | For | Notes |
|---|---|---|
| `mul16.asm` | NASM, 32-bit Linux (OneCompiler) | The algorithm uses only 16-bit registers: product in DX:AX via `ADD` + `ADC`, multiplicand in BX:SI shifted with `SHL` + `RCL`, multiplier shifted with `SHR`. Prints a 16-line step table. |
| `mul16_8086.asm` | MASM/TASM, emu8086 or DOSBox | Classic lab-manual layout (`.MODEL SMALL`, `MOV AX,@DATA`, `INT 21H`). Stores the product in `PROD_HI:PROD_LO` and prints it in hex. |

**Run `mul16.asm` on OneCompiler:** open https://onecompiler.com/assembly, delete the sample, paste the whole of `mul16.asm` and press **Run**. To use other inputs, edit `num1 dw 1234h` / `num2 dw 5678h` at the top. Hex values starting with A–F need a leading 0, e.g. `0FFFFh`.

Or on Linux:

```sh
nasm -f elf32 mul16.asm -o mul16.o && ld -m elf_i386 mul16.o -o mul16 && ./mul16
```

Expected output: 16 step lines, ending with `Product      : 06260060H (103153760)`. The full output is in [USER_MANUAL.md](USER_MANUAL.md#62-mul16asm-with-the-default-inputs-1234h--5678h).

**Run `mul16_8086.asm` in emu8086:** *File → Open*, then *Emulate → Run*. It prints `PRODUCT      : 06260060H`. In DOSBox, copy it as `MUL16.ASM`, then run `MASM MUL16.ASM;`, then `LINK MUL16.OBJ;`, then `MUL16`.

> **Note:** `mul16_8086.asm` has **not been run** on emu8086 or DOSBox, because no MASM/TASM toolchain was available on the development machine. It was checked carefully by eye, and `test_asm.sh` verifies two things automatically: its algorithm block (`MOV SI, NUM1` … `JNZ NEXT_BIT`) is instruction-for-instruction identical to `mul16.asm`'s, which is run and tested on 49 input pairs, and it contains no `MUL`/`IMUL`. The only untested part is the short `PRINT_HEX16` print routine (`ROL BX,CL` by 4, then `INT 21H AH=02H`). Try it once in emu8086 before the demo.

## Assembly programs: Q16

| File | For | Notes |
|---|---|---|
| `count16.asm` | NASM, 32-bit Linux (OneCompiler) | The algorithm uses only 16-bit and 8-bit registers: value in AX, ONES in BL, ZEROS in BH, Count in CX. `SHR AX,1`, then `JNC`, then `INC`, then `LOOP`. Prints the input in hex and binary, a 16-line step table and both counts. |
| `count16_8086.asm` | MASM/TASM, emu8086 or DOSBox | Classic lab-manual layout (`.MODEL SMALL`, `MOV AX,@DATA`, `INT 21H`). Stores the results in the memory variables `ONES` and `ZEROS` and prints them in decimal. |

**Run `count16.asm` on OneCompiler:** open https://onecompiler.com/assembly, delete the sample, paste the whole of `count16.asm` and press **Run**. To use another value, edit `num dw 1234h` at the top. Hex values starting with A–F need a leading 0, e.g. `0FFFFh`.

Or on Linux:

```sh
nasm -f elf32 count16.asm -o count16.o && ld -m elf_i386 count16.o -o count16 && ./count16
```

Real output for the default input 1234H (exit code 0):

```
Count 1s and 0s in AX
AX    : 1234H (0001001000110100b)
Step | CF | Action
 1   | 0  | ZEROS++
 2   | 0  | ZEROS++
 3   | 1  | ONES++
 4   | 0  | ZEROS++
 5   | 1  | ONES++
 6   | 1  | ONES++
 7   | 0  | ZEROS++
 8   | 0  | ZEROS++
 9   | 0  | ZEROS++
10   | 1  | ONES++
11   | 0  | ZEROS++
12   | 0  | ZEROS++
13   | 1  | ONES++
14   | 0  | ZEROS++
15   | 0  | ZEROS++
16   | 0  | ZEROS++
Ones  : 5
Zeros : 11
```

**Run `count16_8086.asm` in emu8086:** *File → Open*, then *Emulate → Run*. It prints `AX    : 1234H`, `ONES  : 5` and `ZEROS : 11`. In DOSBox, copy it as `COUNT16.ASM`, then run `MASM COUNT16.ASM;`, then `LINK COUNT16.OBJ;`, then `COUNT16`.

> **Note:** `count16_8086.asm` has **not been run** on emu8086 or DOSBox, because no MASM/TASM toolchain or DOS emulator was available on the development machine. It was checked carefully by eye, and `test_asm.sh` verifies automatically that its algorithm block (`MOV AX, NUM` … `POP AX`) is instruction-for-instruction identical to `count16.asm`'s, which is run and tested on 50 values. The untested parts are the two short print routines: `PRINT_HEX16` (the same routine as in `mul16_8086.asm`) and `PRINT_DEC8` (`DIV BL` by 10, then `INT 21H AH=02H`). Try it once in emu8086 before the demo.

> **Note on `LOOP` in `count16.asm`:** on a real 8086 `LOOP` counts with CX. OneCompiler assembles the NASM file as 32-bit code, where the same instruction counts with ECX, so the print helpers end with `movzx ecx, cx` to keep ECX equal to CX. The algorithm block itself is unchanged 8086 code.

## Documentation

- [USER_MANUAL.md](USER_MANUAL.md): how to use both pages and run the programs, plus the expected output
- [VIVA_NOTES.md](VIVA_NOTES.md): for each problem, a one-page explanation, a hand-worked example and likely viva questions

## Project structure

```
index.html          Q15 page (HTML + CSS + JS, including the pure shift-and-add core
                    and embedded copies of both Q15 assembly programs)
bitcount.html       Q16 page (HTML + CSS + JS, including the pure bit-count core
                    and embedded copies of both Q16 assembly programs)
test.js             website test suite for both pages (node test.js)
mul16.asm           Q15 NASM program for OneCompiler / 32-bit Linux
mul16_8086.asm      Q15 MASM/TASM program for emu8086 / DOSBox
count16.asm         Q16 NASM program for OneCompiler / 32-bit Linux
count16_8086.asm    Q16 MASM/TASM program for emu8086 / DOSBox
test_asm.sh         assembly test suite for all four programs (./test_asm.sh)
USER_MANUAL.md      user manual
VIVA_NOTES.md       viva preparation notes
```

## Team

| Name | Registration No. |
|---|---|
| TEAM_MEMBER_1 | REG_1 |
| TEAM_MEMBER_2 | REG_2 |
| TEAM_MEMBER_3 | REG_3 |
