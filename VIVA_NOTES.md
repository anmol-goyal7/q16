# Viva Notes

Two pages: **Q15 Shift-and-Add Multiplication** first, then **Q16 Count 1s and 0s in AX**.

# Q15: Shift-and-Add Multiplication

## The idea in simple words

Shift-and-add is **long multiplication in binary**. In decimal long multiplication you multiply M by each digit of Q and write each result one place further left. In binary every digit of Q is **0 or 1**, so each row is either **M itself** or **all zeros**. Multiplying by a bit needs no multiplier at all: you only **add** M when the bit is 1, and **shift** to move one place left.

**Registers (n-bit unsigned operands):** M (multiplicand, kept in 2n bits), Q (multiplier, n bits), P (product, 2n bits, starts at 0), Count (starts at n).

**Each cycle (repeat n times):**

1. If **Q₀ = 1** (lowest bit of Q), then **P = P + M**. Otherwise do nothing.
2. **Shift M left** by 1 (M × 2) and **shift Q right** by 1 (logical, so the next bit becomes Q₀).
3. **Count = Count − 1**. When Count = 0, **P is the product**.

## Hand-worked example: 1101 × 1011 (13 × 11), n = 4

**On paper:**

```
            1 1 0 1      M = 13
          × 1 0 1 1      Q = 11
          ---------
            1 1 0 1      bit 0 = 1  ->  M        = 13
          1 1 0 1 .      bit 1 = 1  ->  M x 2    = 26
        0 0 0 0 . .      bit 2 = 0  ->  0
      1 1 0 1 . . .      bit 3 = 1  ->  M x 8    = 104
  ---------------
  1 0 0 0 1 1 1 1        = 143
```

**In the registers** (M and P are 8 bits):

| Step | Q₀ | Action | M | Q | P | Count |
|---|---|---|---|---|---|---|
| Initial | | | `0000 1101` | `1011` | `0000 0000` | 4 |
| 1 | 1 | Add M: 0 + 13 | `0000 1101` | `1011` | `0000 1101` | 4 |
| | | Shift M left, Q right | `0001 1010` | `0101` | `0000 1101` | 3 |
| 2 | 1 | Add M: 13 + 26 | `0001 1010` | `0101` | `0010 0111` | 3 |
| | | Shift M left, Q right | `0011 0100` | `0010` | `0010 0111` | 2 |
| 3 | 0 | No add | `0011 0100` | `0010` | `0010 0111` | 2 |
| | | Shift M left, Q right | `0110 1000` | `0001` | `0010 0111` | 1 |
| 4 | 1 | Add M: 39 + 104 | `0110 1000` | `0001` | `1000 1111` | 1 |
| | | Shift M left, Q right | `1101 0000` | `0000` | `1000 1111` | 0 |

Count = 0, so stop. **P = `1000 1111` = 143 = 13 × 11 ✓**. The M values that were added (13, 26, 104) are exactly the non-zero rows of the paper method.

## Why ADC is needed

On the 8086 the product of two 16-bit numbers is 32 bits, but each register holds only 16 bits. So P is kept in **DX:AX** and M in **BX:SI**. A 32-bit add is done in two halves:

- `ADD AX, SI` adds the low words. If the result needs 17 bits, the extra bit goes into the **carry flag (CF)**.
- `ADC DX, BX` adds the high words **plus CF**.

With a plain `ADD` for the high words, every carry out of the low word would be lost and the product would be wrong (for example FFFFH × FFFFH would come out wrong). Shifting the 32-bit M works the same way: `SHL SI,1` pushes the top bit of SI into CF, and `RCL BX,1` rotates CF into the bottom of BX.

## Why the product needs 2n bits and can never overflow

The largest n-bit number is 2ⁿ − 1, so the largest product is

(2ⁿ − 1)² = 2²ⁿ − 2ⁿ⁺¹ + 1 < 2²ⁿ

so it **always fits in 2n bits**: for example, 15 × 15 = 225 < 256 and FFFFH × FFFFH = FFFE0001H < 2³². The product of two n-bit numbers can need almost 2n bits, which is why P (and M, which is shifted left n times) must be 2n bits wide. With 2n bits, overflow is impossible.

## Why it only works for unsigned numbers, and how Booth's fixes it

The method gives every bit a positive weight 2ⁱ. In two's complement the top bit has weight **−2ⁿ⁻¹**, so a negative number read as unsigned is a different, large positive number: 4-bit `1111` is −1, but the method treats it as 15, so −1 × 3 comes out as 45 instead of −3.

**Booth's algorithm** fixes this. It looks at two bits, **Q₀ Q₋₁**: it **subtracts** M at the start of a run of 1s and **adds** M just after the run ends, and it uses an **arithmetic** right shift that keeps the sign. The negative weight of the sign bit is handled automatically, so signed numbers work with no correction step. As a bonus, a long run of 1s costs only two operations.

## Complexity

Exactly **n iterations** for n-bit operands (16 for the 8086 program), whatever the values. Each iteration is at most one 2n-bit add plus the shifts, so time is **O(n)** iterations, or O(n²) bit operations. It needs as many additions as there are 1s in the multiplier.

## 10 likely viva questions

**1. Why is it called shift-and-add?**
Its only operations are adding the multiplicand (when the multiplier bit is 1) and shifting, to move to the next bit's weight. You don't need a multiply circuit.

**2. Why do we test Q₀ and shift Q right?**
Q₀ is the bit currently being processed. Shifting Q right brings each bit of the multiplier into the Q₀ position in turn, from bit 0 up to bit n − 1, so the same `TEST DI,1` works every cycle.

**3. Why shift M left?**
Bit *i* of the multiplier has weight 2ⁱ. After *i* left shifts M = M × 2ⁱ, so adding it is exactly "M times that bit's weight". (Hardware versions often keep M fixed and shift the product right instead. That is the same idea.)

**4. Why must the Q shift be logical?**
A logical shift right brings in a 0 at the top. Because the numbers are unsigned, the multiplier is just running out of bits, and the zeros mean "nothing left to add". An arithmetic shift would copy the top bit and could invent extra 1s.

**5. Why is ADC used, and what would happen with ADD?**
P is split over two 16-bit registers. ADC adds the carry from the low-word ADD into the high word. With ADD the carry is lost and large products are wrong.

**6. How big is the product, and can it overflow?**
2n bits (32 bits for 16-bit inputs). It can never overflow, because (2ⁿ − 1)² < 2²ⁿ. The largest 16-bit case, FFFFH × FFFFH = FFFE0001H, still fits.

**7. How many cycles does it take?**
Always n cycles (16 for 16 bits), one per multiplier bit. A Q₀ = 0 cycle still shifts, it just skips the add.

**8. Why not just use MUL?**
The lab is about how multiplication works inside the processor. MUL hides it. Shift-and-add is what a simple multiplier circuit (or microcode) does, and it is how processors without a multiply instruction multiply. Our programs use no MUL or IMUL at all, even for printing: decimal output uses DIV by 10.

**9. What does TEST DI,1 do?**
It ANDs DI with 1 and sets the flags without changing DI. ZF = 1 means bit 0 (Q₀) is 0, so `JZ` skips the add.

**10. Does it work for negative numbers?**
No. It assumes every bit has a positive weight, so negative two's complement numbers give wrong answers. Use Booth's algorithm for signed numbers, or convert to magnitudes, multiply, and fix the sign at the end.

**Bonus: can it finish early?**
Yes. Once Q becomes 0, no more additions can happen, so a program could stop there. The textbook version always runs n cycles, which keeps the timing fixed.

# Q16: Count 1s and 0s in AX

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

## 8 likely viva questions

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
