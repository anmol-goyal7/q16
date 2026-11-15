# User Manual: 8086 Lab Project (Q15 and Q16)

This manual has two parts. **Part 1 (sections 1 to 6)** covers Q15, the Shift-and-Add Multiplication Visualizer (`index.html`). **Part 2 (sections 7 to 12)** covers Q16, Count 1s and 0s in AX (`bitcount.html`). The bar at the top of each page switches between the two.

# Part 1: Q15 Shift-and-Add Multiplication Visualizer

## 1. Launching the Application

The website is one file: `index.html`.

- **Offline (recommended for the demo):** double-click `index.html`, or open it with *File → Open* in any modern browser (Chrome, Edge, Firefox, Safari). You don't need internet, a server or any installation. All styles and scripts are inside the file, and it uses only fonts already on the computer.
- **Online:** open the GitHub Pages link in `README.md`.
- **On a phone:** open the online link. The layout adapts to small screens, and 16-bit registers wrap into two lines of 16 bits.

The app opens on the **Simulator** tab with the hand-worked example 13 × 11 at 4 bits already loaded.

## 2. Using the Simulator

### 2.1 Inputs

| Control | What it does |
|---|---|
| **Multiplicand M** | An unsigned whole number. |
| **Multiplier Q** | An unsigned whole number. |
| **Number base** | **Decimal** or **Hex**. In hex you can type `1234`, `1234H` or `0x1234`. Switching the base rewrites the current values (13 ↔ D). |
| **Bit width n** | 4, 8 or 16 bits. The allowed range is shown under the selector. |
| **Examples** | One-click presets: 13 × 11, 15 × 15, 0 × 9 (4-bit), 1 × 255, 200 × 150 (8-bit), 1234H × 5678H (16-bit, the assembly default) and FFFFH × FFFFH (16-bit maximum). |

The simulation reloads as soon as you type. If a value is not a valid number, is negative, or is too big for the chosen width, a red message appears under that box and the simulator is greyed out until you fix it. A negative number shows: *"No negative numbers: unsigned only - see Booth's for signed."*

### 2.2 Binary setup

Before the first cycle, this card shows:

- **M** and **Q** in binary (n bits each), with their decimal and hex values,
- **P**, the product register: 2n bits wide and starting at 0,
- a green **"No overflow is possible"** note. It shows that the largest n-bit × n-bit product, (2ⁿ − 1)², is smaller than 2²ⁿ, so P can always hold the whole product.

### 2.3 Controls

| Button | Key | Action |
|---|---|---|
| **Next step** | → | Go forward one row of the table |
| **Previous** | ← | Go back one row |
| **Play / Pause** | Space | Step forward automatically every 1.2 seconds. Stops by itself at the last step. |
| **Run all** | End | Jump straight to the final step |
| **Reset** | Home | Go back to the *Initial* row |

You can also click any row of the step table to jump to it. The keyboard shortcuts work whenever the cursor is not inside an input box.

### 2.4 Register diagram

The large bit boxes show the current **M** (2n bits, shifted left each cycle), **Q** (n bits), **P** (2n bits) and **Count**. The registers are right-aligned so that bit 0 of each one lines up.

- The **orange** box is **Q₀**, the rightmost bit of Q. It decides whether M is added.
- Bits that just changed flash blue.
- On an **Add M** step, M has green borders. On a **No add** step, M is faded.
- The badge and the sentence under the registers explain the step, for example *"Q₀ = 1, so add M to P: P = 13 + 26 = 39."*

### 2.5 Long multiplication view

This is the paper method in binary, and it shows *why* the algorithm works:

- M and Q are written at the top. The bit of Q being used right now is orange.
- Below the line there is one row per bit of Q. The row for bit *i* is M shifted left *i* places (dots mark the shifted-in zeros), or **greyed-out zeros** when that bit is 0.
- Rows appear one at a time as you step. The current row is highlighted.
- The line at the bottom is the running sum, which always equals the current P. At the end it is marked *= product ✓*.

### 2.6 Reading the step table

Columns: **Step | Q₀ | Action | M (2n-bit) | Q (n-bit) | P (2n-bit) | Count**

- The first row is **Initial**.
- Each cycle has **two rows**:
  1. the **action row**: Q₀ is shown, and P becomes P + M (green, *Add M*) or stays the same (grey, *No add*);
  2. the **Shift M left, Q right** row (blue): M doubles, Q halves (logical shift) and Count goes down by 1.
- Leading zeros are grey to make the numbers easier to read. Hover over a cell to see its decimal value.
- Rows appear as you step, and the current row is highlighted.

### 2.7 Result

When Count reaches 0, the result card shows:

- the product **P** in binary (2n bits, grouped in nibbles), in hex and in decimal,
- a check line such as `Product = 143 = 13 × 11 ✓`, with the hex form below it. The right-hand side is calculated separately with BigInt multiplication, outside the algorithm, so the tick confirms the algorithm's answer.

## 3. How it Works tab

This tab explains the registers, why M is held in 2n bits, what happens each cycle, why the result equals M × Q, and why it can never overflow. It ends with a flowchart:

Start → P = 0, Count = n → Q₀ = 1? → (Yes: P = P + M) / (No: skip) → shift M left, Q right → Count = Count − 1 → Count = 0? → (No: back to the Q₀ test) / (Yes: End, product = P).

The **Shift-add vs Booth's** tab compares this method with Booth's algorithm: unsigned vs signed, runs of 1s, and a side-by-side table. It also has a live line that counts the additions each method would need for the multiplier currently loaded, plus a link to the Booth's visualizer.

## 4. 8086 Assembly tab and running the programs

The tab shows both programs with syntax highlighting. It has a **Copy code** button, a link to OneCompiler, the real output of `mul16.asm`, and a table of which instructions carry out which step (TEST for Q₀, ADD + ADC for P = P + M, SHL + RCL to shift M, SHR to shift Q). The button *Show 1234H × 5678H in the simulator* loads the same inputs as the program, so you can compare its 16 partial products with the step table.

### 4.1 mul16.asm on OneCompiler (NASM, 32-bit Linux)

1. Open https://onecompiler.com/assembly.
2. Delete the sample program.
3. Paste the whole of `mul16.asm` (or press **Copy code** on the 8086 Assembly tab).
4. Press **Run**.

To multiply other numbers, change the two lines at the top of the program:

```nasm
num1        dw 1234h            ; multiplicand M
num2        dw 5678h            ; multiplier   Q
```

A hex value that starts with A–F needs a leading 0, for example `0FFFFh`.

To run it on Linux instead: `nasm -f elf32 mul16.asm -o mul16.o && ld -m elf_i386 mul16.o -o mul16 && ./mul16`

### 4.2 mul16_8086.asm in emu8086 or DOSBox (MASM/TASM)

- **emu8086:** *File → Open* `mul16_8086.asm`, then *Emulate → Run*. The output appears in the emulator screen.
- **DOSBox with MASM:** copy the file as `MUL16.ASM` (DOS needs 8.3 file names), then run `MASM MUL16.ASM;`, then `LINK MUL16.OBJ;`, then `MUL16`. With TASM, use `TASM MUL16.ASM`, then `TLINK MUL16.OBJ`, then `MUL16`.

It prints the inputs and the product in hex. The product is also stored in the variables `PROD_HI:PROD_LO`, which you can inspect in emu8086's variables window. Expected output:

```
SHIFT-AND-ADD MULTIPLICATION (NO MUL)
MULTIPLICAND : 1234H
MULTIPLIER   : 5678H
PRODUCT      : 06260060H
```

## 5. Important Notes

- **Fully offline:** no CDNs, web fonts or network requests. The file works from a USB stick.
- **Unsigned only:** negative numbers are rejected. For signed multiplication, use Booth's algorithm.
- **Supported bit widths and ranges:**

  | Width | Range (decimal) | Range (hex) | Product width |
  |---|---|---|---|
  | 4 bits | 0 to 15 | 0H to FH | 8 bits |
  | 8 bits | 0 to 255 | 00H to FFH | 16 bits |
  | 16 bits | 0 to 65535 | 0000H to FFFFH | 32 bits |

- **No overflow:** the product always fits in 2n bits, because (2ⁿ − 1)² < 2²ⁿ. For example, FFFFH × FFFFH = FFFE0001H.
- **Correctness:**
  - `node test.js` checks every input pair at 4 and 8 bits, plus 50,000 random pairs and all extreme pairs at 16 bits, against BigInt multiplication. It tests the same code that runs in the page.
  - `./test_asm.sh` assembles and runs `mul16.asm` for 49 input pairs and checks its full output.
- Light theme by default. Use the **Dark mode** button at the top right; the browser remembers your choice.

## 6. Expected Output

### 6.1 13 × 11 at 4 bits (the hand-worked example)

M = 13 = `1101`, Q = 11 = `1011`, P = `0000 0000` (8 bits), Count = 4

| Step | Q₀ | Action | M (8-bit) | Q | P (8-bit) | Count |
|---|---|---|---|---|---|---|
| Initial |  | Initialise | `0000 1101` | `1011` | `0000 0000` | 4 |
| 1 | 1 | Add M | `0000 1101` | `1011` | `0000 1101` | 4 |
|  |  | Shift M left, Q right | `0001 1010` | `0101` | `0000 1101` | 3 |
| 2 | 1 | Add M | `0001 1010` | `0101` | `0010 0111` | 3 |
|  |  | Shift M left, Q right | `0011 0100` | `0010` | `0010 0111` | 2 |
| 3 | 0 | No add | `0011 0100` | `0010` | `0010 0111` | 2 |
|  |  | Shift M left, Q right | `0110 1000` | `0001` | `0010 0111` | 1 |
| 4 | 1 | Add M | `0110 1000` | `0001` | `1000 1111` | 1 |
|  |  | Shift M left, Q right | `1101 0000` | `0000` | `1000 1111` | 0 |

**Product = P = `1000 1111` = 8FH = 143**, check: `Product = 143 = 13 × 11 ✓`

`node test.js` checks this table row by row.

### 6.2 mul16.asm with the default inputs 1234H × 5678H

Real output, copied from a run (`nasm -f elf32`, `ld -m elf_i386`, exit code 0):

```
Shift-and-Add Multiplication (no MUL)
Multiplicand : 1234H (4660)
Multiplier   : 5678H (22136)
Step | Q0 | Action | Partial Product
 1   | 0  | SKIP   | 00000000H
 2   | 0  | SKIP   | 00000000H
 3   | 0  | SKIP   | 00000000H
 4   | 1  | ADD M  | 000091A0H
 5   | 1  | ADD M  | 0001B4E0H
 6   | 1  | ADD M  | 0003FB60H
 7   | 1  | ADD M  | 00088860H
 8   | 0  | SKIP   | 00088860H
 9   | 0  | SKIP   | 00088860H
10   | 1  | ADD M  | 002CF060H
11   | 1  | ADD M  | 0075C060H
12   | 0  | SKIP   | 0075C060H
13   | 1  | ADD M  | 01990060H
14   | 0  | SKIP   | 01990060H
15   | 1  | ADD M  | 06260060H
16   | 0  | SKIP   | 06260060H
Product      : 06260060H (103153760)
```

Check: 4660 × 22136 = 103153760 = 06260060H ✓. Step *k* uses bit *k* − 1 of 5678H = `0101 0110 0111 1000`, read from the right. The **1234H × 5678H** preset in the simulator shows the same 16 partial products, and `./test_asm.sh` checks that they match.

# Part 2: Q16 Count 1s and 0s in AX

## 7. Launching the Application

The Q16 website is one file: `bitcount.html`.

- **Offline (recommended for the demo):** double-click `bitcount.html`, or click **Q16 Count 1s and 0s in AX** in the bar at the top of `index.html`. You don't need internet, a server or any installation. Keep `index.html` and `bitcount.html` in the same folder so the bar can switch between them; each page also works on its own.
- **Online:** open the Q16 GitHub Pages link in `README.md`.
- **On a phone:** open the online link. The layout adapts to small screens.

The page opens on the **Simulator** tab with AX = 1234H already loaded, the same value as the assembly program.

## 8. Using the Simulator

### 8.1 Input

| Control | What it does |
|---|---|
| **Value loaded into AX** | One unsigned 16-bit number, 0 to 65535 (0000H to FFFFH). |
| **Number base** | **Hex** or **Decimal**. In hex you can type `1234`, `1234H` or `0x1234`. Switching the base rewrites the current value (1234 ↔ 4660). |
| **Examples** | One-click presets: 0000H (all zeros), FFFFH (all ones), AAAAH (alternating), 8001H (edges only), 00FFH and 1234H (the assembly default). |

The simulation reloads as soon as you type. If the value is not a valid number, is negative, or is bigger than FFFFH, a red message appears under the box and the simulator is greyed out until you fix it.

### 8.2 Controls

| Button | Key | Action |
|---|---|---|
| **Next step ▶** | → | Shift one more bit out of AX |
| **◀ Previous** | ← | Go back one step |
| **▶ Play / ❚❚ Pause** | Space | Auto-step every 1.2 seconds |
| **Run all ⏭** | End | Jump to the final step |
| **↺ Reset** | Home | Back to the initial state |

You can also click any row of the step table to jump to it.

### 8.3 Register view

- **AX** is drawn as 16 bit boxes. The highlighted box on the right is bit 0, the bit that will leave next.
- **CF** is the box to the right of the arrow. After each step it holds the bit that was just shifted out (green for 1, blue for 0).
- **Saved AX** shows the copy made before the loop (`PUSH AX` in the assembly). It never changes, while AX itself is shifted away to 0000H. At the end `POP AX` puts it back.
- **ONES**, **ZEROS** and **Count** are shown as big numbers.
- When you step forward, the bits slide one place right, the outgoing bit drops into CF and the matching counter ticks. The line under the counters gives the reason, for example *"CF = 1, so ONES++ (ONES = 1). Count = 13."*
- The **Invariant** line shows ONES + ZEROS at every step. It always equals the number of bits examined so far (16 − Count), and reaches 16 at the end.

### 8.4 Reading the step table

Columns: **Step | AX (binary) | CF | Action | ONES | ZEROS | Count**. The first row is *Initial* (AX as loaded, counters 0, Count 16). Each later row shows the registers **after** that step's shift: AX one place further right, CF = the bit that came out, the action taken (*ONES++* or *ZEROS++*) and the new counter values.

### 8.5 Result

When Count reaches 0, the Result panel shows ONES and ZEROS, the check `ONES + ZEROS = 16 ✓`, and an **independent check** computed outside the algorithm: the page writes the value in binary with `value.toString(2)` and counts the `1` characters.

## 9. How it Works and Other methods tabs

- **How it works:** a short explanation of shift-and-count and the carry flag, the invariant, the 1234H example, and an SVG flowchart: Start → save AX, ONES = 0, ZEROS = 0, Count = 16 → SHR AX,1 → CF = 1? → ONES++ or ZEROS++ → Count − 1 → Count = 0? → End.
- **Other methods:** ROL (AX is intact after 16 rotations), TEST with a mask, Kernighan's `x & (x − 1)` trick with a live count for the value you entered, a comparison table, and why shift-and-count is the textbook method.

## 10. 8086 Assembly tab and running the programs

The tab shows both programs with syntax highlighting. It has a **Copy code** button, a link to OneCompiler, the real output of `count16.asm`, and a table of which instructions carry out which step (SHR for the shift, JNC/JC to test CF, INC for the counters, LOOP = DEC CX + JNZ for Count). The button *Show 1234H in the simulator* loads the program's default input.

### 10.1 count16.asm on OneCompiler (NASM, 32-bit Linux)

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

### 10.2 count16_8086.asm in emu8086 or DOSBox (MASM/TASM)

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

## 11. Important Notes

- **Fully offline:** no CDNs, web fonts or network requests. Both pages work from a USB stick.
- **16 bits only:** AX is a 16-bit register, so the value must be 0 to FFFFH. For a negative number, enter its 16-bit two's complement pattern (for example −1 is FFFFH).
- **AX is destroyed by the loop:** after 16 shifts AX is 0000H. The program saves it first and restores it afterwards, and the page shows the saved copy.
- **ONES + ZEROS is always 16** at the end. If you only need one count, the other is 16 minus it.
- The theme choice (light or dark) is shared between the Q15 and Q16 pages.

## 12. Expected Output

### 12.1 AX = 1234H (the hand-worked example)

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

### 12.2 count16.asm with the default input 1234H

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

The CF column is the same as the CF column of the table in 12.1. `./test_asm.sh` checks that automatically.
