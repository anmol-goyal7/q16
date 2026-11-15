# Shift-and-Add Multiplication Visualizer

An interactive, step-by-step visualizer for **unsigned shift-and-add binary multiplication**, plus working **8086 assembly programs** that multiply two 16-bit numbers without the `MUL` instruction. Built for COA lab problem 15: *"Multiply two 16-bit numbers using the shift-and-add method instead of using the native MUL instruction."* A sibling project of the Booth's Multiplication Algorithm Visualizer.

**Live demo:** https://anmol-goyal7.github.io/shift-add-multiplier-visualizer/

## Features

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

## Run it locally

No build step and no dependencies. Either:

- open `index.html` directly in a browser (double-click it), or
- serve the folder: `python3 -m http.server`, then visit http://localhost:8000

## Run the tests

```sh
node test.js        # the website's algorithm (any recent Node.js)
./test_asm.sh       # the assembly programs (needs nasm, ld, python3, node)
```

`test.js` extracts the `<script id="shiftadd-core">` block from `index.html` and runs it in a Node VM, so it tests the exact code the page runs. It checks:

- every (M, Q) pair at 4 bits (256) and 8 bits (65,536),
- 50,000 seeded random pairs plus every combination of extremes (0, 1, max − 1, max and all powers of 2) at 16 bits, against BigInt `a * b`,
- every row of every trace: an add happens exactly when Q0 = 1, P changes by exactly M or 0, M doubles, Q halves, Count goes down,
- the 13 × 11 hand-worked trace at 4 bits, row by row,
- input parsing and validation (decimal, hex, ranges, negatives, widths),
- that the programs shown on the 8086 tab are identical to `mul16.asm` and `mul16_8086.asm`.

`test_asm.sh` substitutes each test case into a copy of `mul16.asm`, then assembles it (`nasm -f elf32`), links it (`ld -m elf_i386`), runs it and compares the whole output, including the parsed Product line, with python3. It checks:

- the cases 0×0, 0×1234H, 1×1, 1×FFFFH, FFFFH×FFFFH, 8000H×2, 00FFH×00FFH, 1234H×5678H and 000DH×000BH, plus 40 seeded random pairs,
- that neither `.asm` file contains a `MUL` or `IMUL` instruction (with a self-test of the detector),
- that the MASM program's algorithm block is identical, instruction for instruction, to the tested NASM one,
- that the website's trace matches the program's 16 partial products for 1234H × 5678H,
- that the output shown on the 8086 tab is a real run, and that the program also works as 64-bit code (`nasm -f elf64`).

## Assembly programs

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

## Documentation

- [USER_MANUAL.md](USER_MANUAL.md): how to use the app and run the programs, plus the expected output
- [VIVA_NOTES.md](VIVA_NOTES.md): a one-page explanation, the hand-worked 1101 × 1011 example and likely viva questions

## Project structure

```
index.html        the whole app (HTML + CSS + JS, including the pure shift-and-add core
                  and embedded copies of both assembly programs)
test.js           website test suite (node test.js)
mul16.asm         NASM program for OneCompiler / 32-bit Linux
mul16_8086.asm    MASM/TASM program for emu8086 / DOSBox
test_asm.sh       assembly test suite (./test_asm.sh)
USER_MANUAL.md    user manual
VIVA_NOTES.md     viva preparation notes
```

## Team

| Name | Registration No. |
|---|---|
| TEAM_MEMBER_1 | REG_1 |
| TEAM_MEMBER_2 | REG_2 |
| TEAM_MEMBER_3 | REG_3 |
