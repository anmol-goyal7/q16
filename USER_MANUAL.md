# User Manual: Count 1s and 0s in AX (Q16)

## 1. Launching the Application

The website is one file: `index.html`.

- **Offline (recommended for the demo):** double-click `index.html`, or open it with *File → Open* in any modern browser (Chrome, Edge, Firefox, Safari). You don't need internet, a server or any installation. All styles and scripts are inside the file, and it uses only fonts already on the computer.
- **Online:** open the GitHub Pages link in `README.md`.
- **On a phone:** open the online link. The layout adapts to small screens.

The page opens on the **Simulator** tab with AX = 1234H already loaded, the same value as the assembly program.

## 2. Using the Simulator

### 2.1 Input

| Control | What it does |
|---|---|
| **Value loaded into AX** | One unsigned 16-bit number, 0 to 65535 (0000H to FFFFH). |
| **Number base** | **Hex** or **Decimal**. In hex you can type `1234`, `1234H` or `0x1234`. Switching the base rewrites the current value (1234 ↔ 4660). |
| **Examples** | One-click presets: 0000H (all zeros), FFFFH (all ones), AAAAH (alternating), 8001H (edges only), 00FFH and 1234H (the assembly default). |

The simulation reloads as soon as you type. If the value is not a valid number, is negative, or is bigger than FFFFH, a red message appears under the box and the simulator is greyed out until you fix it.

### 2.2 Controls

| Button | Key | Action |
|---|---|---|
| **Next step ▶** | → | Shift one more bit out of AX |
| **◀ Previous** | ← | Go back one step |
| **▶ Play / ❚❚ Pause** | Space | Auto-step every 1.2 seconds |
| **Run all ⏭** | End | Jump to the final step |
| **↺ Reset** | Home | Back to the initial state |

You can also click any row of the step table to jump to it. The keyboard shortcuts work whenever the cursor is not inside an input box.

### 2.3 Register view

- **AX** is drawn as 16 bit boxes. The highlighted box on the right is bit 0, the bit that will leave next.
- **CF** is the box to the right of the arrow. After each step it holds the bit that was just shifted out (green for 1, blue for 0).
- **Saved AX** shows the copy made before the loop (`PUSH AX` in the assembly). It never changes, while AX itself is shifted away to 0000H. At the end `POP AX` puts it back.
- **ONES**, **ZEROS** and **Count** are shown as big numbers.
- When you step forward, the bits slide one place right, the outgoing bit drops into CF and the matching counter ticks. The line under the counters gives the reason, for example *"CF = 1, so ONES++ (ONES = 1). Count = 13."*
- The **Invariant** line shows ONES + ZEROS at every step. It always equals the number of bits examined so far (16 − Count), and reaches 16 at the end.

### 2.4 Reading the step table

Columns: **Step | AX (binary) | CF | Action | ONES | ZEROS | Count**. The first row is *Initial* (AX as loaded, counters 0, Count 16). Each later row shows the registers **after** that step's shift: AX one place further right, CF = the bit that came out, the action taken (*ONES++* or *ZEROS++*) and the new counter values.

### 2.5 Result

When Count reaches 0, the Result panel shows ONES and ZEROS, the check `ONES + ZEROS = 16 ✓`, and an **independent check** computed outside the algorithm: the page writes the value in binary with `value.toString(2)` and counts the `1` characters.

## 3. How it Works and Other methods tabs

- **How it works:** a short explanation of shift-and-count and the carry flag, the invariant, the 1234H example, and an SVG flowchart: Start → save AX, ONES = 0, ZEROS = 0, Count = 16 → SHR AX,1 → CF = 1? → ONES++ or ZEROS++ → Count − 1 → Count = 0? → End.
- **Other methods:** ROL (AX is intact after 16 rotations), TEST with a mask, Kernighan's `x & (x − 1)` trick with a live count for the value you entered, a comparison table, and why shift-and-count is the textbook method.

## 4. 8086 Assembly tab and running the programs

The tab shows both programs with syntax highlighting. It has a **Copy code** button, a link to OneCompiler, the real output of `count16.asm`, and a table of which instructions carry out which step (SHR for the shift, JNC/JC to test CF, INC for the counters, LOOP = DEC CX + JNZ for Count). The button *Show 1234H in the simulator* loads the program's default input.

### 4.1 count16.asm on OneCompiler (NASM, 32-bit Linux)

1. Open https://onecompiler.com/assembly.
2. Delete the sample program.
3. Paste the whole of `count16.asm` (or press **Copy code** on the 8086 Assembly tab).
4. Press **Run**.

To count the bits of another value, change this line at the top of the program:

```nasm
num         dw 1234h            ; the value loaded into AX
```

A hex value that starts with A–F needs a leading 0, for example `0FFFFh`.

To run it on Linux instead: `nasm -f elf32 count16.asm -o count16.o && ld -m elf_i386 count16.o -o count16 && ./count16`

### 4.2 count16_8086.asm in emu8086 or DOSBox (MASM/TASM)

- **emu8086:** *File → Open* `count16_8086.asm`, then *Emulate → Run*. The output appears in the emulator screen.
- **DOSBox with MASM:** copy the file as `COUNT16.ASM` (DOS needs 8.3 file names), then run `MASM COUNT16.ASM;`, then `LINK COUNT16.OBJ;`, then `COUNT16`. With TASM, use `TASM COUNT16.ASM`, then `TLINK COUNT16.OBJ`, then `COUNT16`.

It prints the input in hex and both counts in decimal. The counts are also stored in the variables `ONES` and `ZEROS`, which you can inspect in emu8086's variables window. Expected output:

```
COUNT 1S AND 0S IN AX
AX    : 1234H
ONES  : 5
ZEROS : 11
```

This program has not been run on emu8086 or DOSBox (no MASM/TASM toolchain was available). Its algorithm block is checked automatically against the tested NASM program; see the note in `README.md`. Try it once before the demo.

## 5. Important Notes

- **Fully offline:** no CDNs, web fonts or network requests. The page works from a USB stick.
- **16 bits only:** AX is a 16-bit register, so the value must be 0 to FFFFH. For a negative number, enter its 16-bit two's complement pattern (for example −1 is FFFFH).
- **AX is destroyed by the loop:** after 16 shifts AX is 0000H. The program saves it first and restores it afterwards, and the page shows the saved copy.
- **ONES + ZEROS is always 16** at the end. If you only need one count, the other is 16 minus it.
- **Correctness:**
  - `node test.js` checks all 65,536 possible values of AX against an independent bit count. It tests the same code that runs in the page.
  - `./test_asm.sh` assembles and runs `count16.asm` for 50 values and checks its full output.
- Light theme by default. Use the **Dark mode** button at the top right; the browser remembers your choice.

## 6. Expected Output

### 6.1 AX = 1234H (the hand-worked example)

AX = 1234H = `0001 0010 0011 0100`, ONES = 0, ZEROS = 0, Count = 16

| Step | AX (binary) | CF | Action | ONES | ZEROS | Count |
|---|---|---|---|---|---|---|
| Initial | `0001 0010 0011 0100` |  | Save AX | 0 | 0 | 16 |
| 1 | `0000 1001 0001 1010` | 0 | ZEROS++ | 0 | 1 | 15 |
| 2 | `0000 0100 1000 1101` | 0 | ZEROS++ | 0 | 2 | 14 |
| 3 | `0000 0010 0100 0110` | 1 | ONES++ | 1 | 2 | 13 |
| 4 | `0000 0001 0010 0011` | 0 | ZEROS++ | 1 | 3 | 12 |
| 5 | `0000 0000 1001 0001` | 1 | ONES++ | 2 | 3 | 11 |
| 6 | `0000 0000 0100 1000` | 1 | ONES++ | 3 | 3 | 10 |
| 7 | `0000 0000 0010 0100` | 0 | ZEROS++ | 3 | 4 | 9 |
| 8 | `0000 0000 0001 0010` | 0 | ZEROS++ | 3 | 5 | 8 |
| 9 | `0000 0000 0000 1001` | 0 | ZEROS++ | 3 | 6 | 7 |
| 10 | `0000 0000 0000 0100` | 1 | ONES++ | 4 | 6 | 6 |
| 11 | `0000 0000 0000 0010` | 0 | ZEROS++ | 4 | 7 | 5 |
| 12 | `0000 0000 0000 0001` | 0 | ZEROS++ | 4 | 8 | 4 |
| 13 | `0000 0000 0000 0000` | 1 | ONES++ | 5 | 8 | 3 |
| 14 | `0000 0000 0000 0000` | 0 | ZEROS++ | 5 | 9 | 2 |
| 15 | `0000 0000 0000 0000` | 0 | ZEROS++ | 5 | 10 | 1 |
| 16 | `0000 0000 0000 0000` | 0 | ZEROS++ | 5 | 11 | 0 |

**ONES = 5, ZEROS = 11**, check: `ONES + ZEROS = 5 + 11 = 16 ✓`. AX is 0000H after the loop and `POP AX` restores 1234H.

`node test.js` checks this table row by row.

### 6.2 count16.asm with the default input 1234H

Real output, copied from a run (`nasm -f elf32`, `ld -m elf_i386`, exit code 0):

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

The CF column is the same as the CF column of the table in 6.1. `./test_asm.sh` checks that automatically.
