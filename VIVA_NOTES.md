# Viva Notes: Q16 Count 1s and 0s in AX

## The idea in simple words

The 8086 has no instruction that counts bits, so we look at the 16 bits of AX **one at a time**. Shifting AX right by one place pushes its lowest bit out, and the 8086 puts that bit in the **carry flag (CF)**. We then test CF: if it is 1 we add 1 to ONES, otherwise we add 1 to ZEROS. After 16 shifts every bit has been through CF once.

**Registers:** AX (the value), BL = ONES, BH = ZEROS, CX = Count (starts at 16).

**Each cycle (repeat 16 times):**

1. `SHR AX,1`: shift AX right by 1 (logical). The bit shifted out goes into **CF**.
2. If **CF = 1** then **ONES = ONES + 1**, otherwise **ZEROS = ZEROS + 1** (`JNC`, `INC BL` / `INC BH`).
3. **Count = Count − 1** (`LOOP`). When Count = 0, stop.

## Hand-worked example: B5H = 1011 0101b (8 bits, so Count = 8)

| Step | AL after the shift | CF | Action | ONES | ZEROS | Count |
|---|---|---|---|---|---|---|
| Initial | `1011 0101` | | | 0 | 0 | 8 |
| 1 | `0101 1010` | 1 | ONES++ | 1 | 0 | 7 |
| 2 | `0010 1101` | 0 | ZEROS++ | 1 | 1 | 6 |
| 3 | `0001 0110` | 1 | ONES++ | 2 | 1 | 5 |
| 4 | `0000 1011` | 0 | ZEROS++ | 2 | 2 | 4 |
| 5 | `0000 0101` | 1 | ONES++ | 3 | 2 | 3 |
| 6 | `0000 0010` | 1 | ONES++ | 4 | 2 | 2 |
| 7 | `0000 0001` | 0 | ZEROS++ | 4 | 3 | 1 |
| 8 | `0000 0000` | 1 | ONES++ | 5 | 3 | 0 |

Count = 0, so stop. **ONES = 5, ZEROS = 3, and 5 + 3 = 8 ✓**. The CF column read from top to bottom (1, 0, 1, 0, 1, 1, 0, 1) is B5H read from right to left. The 16-bit program does the same thing with AX and Count = 16; for 1234H it gives ONES = 5 and ZEROS = 11.

## Why SHR puts the bit into CF

A register has a fixed number of bits, so when everything moves one place right the old bit 0 has nowhere to go inside the register. The 8086 is designed to keep that bit in the carry flag instead of throwing it away. So after `SHR AX,1`: bit 15 = 0, each other bit holds its left neighbour's old value, and **CF = old bit 0**. `JC` (jump if carry) and `JNC` (jump if no carry) can then branch on it. `SHR AX,1` also divides an unsigned AX by 2, and CF is the remainder.

## Why ZEROS = 16 − ONES (one counter would be enough)

Every cycle adds 1 to exactly one of the two counters, and there are 16 cycles. So **ONES + ZEROS = 16** always, which means ZEROS = 16 − ONES. A shorter program could count only the 1s and finish with `MOV BH,16` / `SUB BH,BL`. We keep both counters because the problem asks for both counts, and because the sum being 16 is a free check that the loop ran correctly.

## Why the original AX must be saved

`SHR` changes AX itself. After 16 shifts every original bit has been pushed out and replaced by a 0, so **AX = 0000H**: the value we were asked about is gone. If the rest of the program still needs it (here, to print it, and in general because the caller expects AX to be unchanged), it must be saved first. The program uses `PUSH AX` before the loop and `POP AX` after it; copying it to another register or a memory variable would also work.

## ROL vs SHR

| | `SHR AX,1` | `ROL AX,1` |
|---|---|---|
| Bit that goes to CF | bit 0 (lowest) | bit 15 (highest) |
| What enters the other end | a 0 | the same bit that went to CF |
| AX after 16 times | 0000H (destroyed) | the original value (intact) |
| Need to save AX? | yes | no |
| Order the bits are seen | right to left | left to right |

Both give the same counts. `ROL` (or `ROR`) saves the `PUSH`/`POP`; `SHR` is the usual textbook choice because "shift a bit into carry, then test carry" is the simplest thing to explain.

## Complexity

Always **16 cycles**, whatever the value. Each cycle is one shift, one conditional jump, one increment and the `LOOP`. For an n-bit register it is n cycles.

## Execution time (8086 clock cycles)

Counted for the bit-counting part only (`MOV AX,NUM` to `MOV ZEROS,BH`), using Intel's 8086 instruction timings. The printing (`INT 21H`) runs DOS code and is not counted.

| Instructions | Cycles | Runs |
|---|---|---|
| `MOV AX,NUM` | 10 | once |
| `PUSH AX` | 11 | once |
| `XOR BL,BL` + `XOR BH,BH` | 3 + 3 | once |
| `MOV CX,16` | 4 | once |
| Bit = 1: `SHR` 2 + `JNC` not taken 4 + `INC BL` 3 + `JMP` 15 | **24** | once per 1 bit |
| Bit = 0: `SHR` 2 + `JNC` taken 16 + `INC BH` 3 | **21** | once per 0 bit |
| `LOOP next_bit` | 17 when it jumps, 5 when it falls through | 15 × 17 + 5 = 260 |
| `POP AX` | 8 | once |
| `MOV ONES,BL` + `MOV ZEROS,BH` | 15 + 15 | once |

**Total = 329 + 24 × ONES + 21 × ZEROS cycles.**

- **1234H** (5 ones, 11 zeros): 329 + 120 + 231 = **680 cycles**, about **136 µs** on a 5 MHz 8086 (1 cycle = 0.2 µs).
- **Fastest**, 0000H: 665 cycles (133 µs). **Slowest**, FFFFH: 713 cycles (142.6 µs).

The loop always runs 16 times. The time still depends a little on the value, because a 1 bit costs 3 cycles more than a 0 bit: it takes the extra `JMP COUNTED`, while a 0 bit takes the `JNC` jump. These are textbook figures and ignore prefetch-queue and memory wait-state effects. On a modern PC, `count16.asm` takes about 0.2 ms per run, and almost all of that is Linux starting the process and printing.

## 9 likely viva questions

**1. Which flag is used and why?**
The carry flag. `SHR` copies the bit it shifts out into CF, so testing CF tells us whether that bit was 1 or 0.

**2. Why JNC and not JZ?**
`JZ` tests the zero flag, which says whether the **whole result** is zero, not what the shifted-out bit was. The bit we want is in CF, so we need `JC` or `JNC`.

**3. What is in AX after the loop?**
0000H. All 16 bits have been shifted out and zeros shifted in. That is why the original is saved with `PUSH AX` and restored with `POP AX`.

**4. What does LOOP do?**
It subtracts 1 from CX and jumps to the label if CX is not 0. It is `DEC CX` + `JNZ` in one instruction (except that `LOOP` does not change the flags). CX starts at 16, so the body runs 16 times.

**5. Does INC change the carry flag?**
No. `INC` and `DEC` change the other arithmetic flags but leave CF alone. Here it does not matter, because CF has already been tested by `JNC` before the `INC`.

**6. What is the largest value ONES or ZEROS can reach? Is an 8-bit register enough?**
16 (ONES for FFFFH, ZEROS for 0000H). An 8-bit register holds up to 255, so BL and BH are more than enough.

**7. Would SAR or SHL work instead of SHR?**
`SHL` works the same way but sends bit 15 to CF, so the bits are seen from the left. `SAR` also sends bit 0 to CF, so the counts come out right, but it copies the sign bit back in at the top, so AX ends as FFFFH instead of 0000H for a negative value. `SHR` is the plain logical shift.

**8. How would you make it faster?**
Stop as soon as AX becomes 0 (the remaining bits are all zeros, so ZEROS = 16 − ONES), or use Kernighan's trick: `x = x AND (x − 1)` clears the lowest 1 bit, so the loop runs once per 1 bit instead of 16 times. Newer processors have a single `POPCNT` instruction; the 8086 does not.

**9. How long does the program take to execute?**
About **680 clock cycles** for 1234H, which is about **136 µs** on a 5 MHz 8086 (see *Execution time* above). In general it takes 329 + 24 × ONES + 21 × ZEROS cycles, so 665 to 713 cycles depending on the value. The loop always runs 16 times, but a 1 bit costs 3 cycles more than a 0 bit because of the extra `JMP`.
