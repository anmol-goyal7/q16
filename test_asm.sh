#!/usr/bin/env bash
# Tests for the assembly programs count16.asm and count16_8086.asm.
# Run with: ./test_asm.sh
# Needs: nasm, ld (binutils), python3, node.
#
# For every test value the input is substituted into a temporary copy of
# count16.asm, which is assembled (nasm -f elf32), linked (ld -m elf_i386)
# and run. The Ones and Zeros lines are parsed and checked against
# python's bit count, and the whole output is compared with the output
# python3 expects.

set -u
cd "$(dirname "$0")"
BUILD=build/asmtest
mkdir -p "$BUILD"

pass=0
fail=0
ok()  { pass=$((pass + 1)); }
bad() { fail=$((fail + 1)); echo "FAIL  $*"; }

for tool in nasm ld python3 node; do
  command -v "$tool" >/dev/null || { echo "FAIL  $tool is not installed"; exit 1; }
done

# Removes comments and string literals, so only instructions are compared.
strip_asm() { sed -e 's/;.*//' -e "s/'[^']*'//g" -e 's/"[^"]*"//g' "$1"; }

# ---------------------------------------------------------------------
# 1. The MASM program runs the same algorithm instructions as the tested
#    NASM program (from loading AX to restoring it after the loop).
# ---------------------------------------------------------------------
algo16() {
  strip_asm "$1" | tr 'A-Z' 'a-z' | tr -d '[]' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//; s/ ?, ?/,/g' |
    awk '/^mov ax,num$/ {on=1} on && $0 != "" && $1 != "call" {print} on && /^pop ax$/ {on=0}'
}
algo16 count16.asm > "$BUILD/algo16_nasm.txt"
algo16 count16_8086.asm > "$BUILD/algo16_masm.txt"
if [ "$(wc -l < "$BUILD/algo16_nasm.txt")" -ge 13 ] && cmp -s "$BUILD/algo16_nasm.txt" "$BUILD/algo16_masm.txt"; then
  ok; echo "PASS  count16: MASM algorithm block is identical to the NASM one ($(wc -l < "$BUILD/algo16_nasm.txt") lines)"
else
  bad "count16: MASM and NASM algorithm blocks differ:"; diff "$BUILD/algo16_nasm.txt" "$BUILD/algo16_masm.txt"
fi
algo_ok=1
for ins in 'push ax' 'xor bl,bl' 'xor bh,bh' 'mov cx,16' 'shr ax,1' 'jnc bit_zero' 'inc bl' 'inc bh' 'loop next_bit' 'pop ax'; do
  grep -qxF "$ins" "$BUILD/algo16_nasm.txt" || { bad "count16.asm algorithm is missing: $ins"; algo_ok=0; }
done
[ $algo_ok = 1 ] && { ok; echo "PASS  count16 algorithm uses SHR AX,1 + JNC + INC BL / INC BH + LOOP, with PUSH AX / POP AX around it"; }
masm_ok=1
for pat in '^\.MODEL SMALL' '^\.STACK' '^\.DATA' '^\.CODE' 'MOV AX, @DATA' 'MOV DS, AX' 'ONES +DB' 'ZEROS +DB' \
           'MOV ONES, BL' 'MOV ZEROS, BH' 'MOV AH, 09H' 'MOV AH, 02H' 'MOV AH, 4CH' '^END MAIN'; do
  grep -qE "$pat" count16_8086.asm || { bad "count16_8086.asm is missing: $pat"; masm_ok=0; }
done
[ $masm_ok = 1 ] && { ok; echo "PASS  count16_8086.asm has the lab-manual structure (.MODEL SMALL ... MOV AH,4CH / INT 21H)"; }

# ---------------------------------------------------------------------
# 2. Build and run count16.asm for each case
# ---------------------------------------------------------------------
expected16() {   # exact output count16.asm must print for input $1 (hex)
  python3 - "$1" <<'PY'
import sys
v = int(sys.argv[1], 16)
out = ["Count 1s and 0s in AX",
       f"AX    : {v:04X}H ({v:016b}b)",
       "Step | CF | Action"]
ones = 0
for i in range(16):
    cf = (v >> i) & 1
    ones += cf
    out.append(f"{i + 1:2d}   | {cf}  | {'ONES++' if cf else 'ZEROS++'}")
out.append(f"Ones  : {ones}")
out.append(f"Zeros : {16 - ones}")
print("\n".join(out))
PY
}

build_run16() {   # $1 = hex input; $2 = format (elf32|elf64). Output -> $BUILD/out16.txt
  local src="$BUILD/case16.asm"
  sed -E "s/^([[:space:]]*num[[:space:]]+dw[[:space:]]+)[0-9A-Fa-f]+h/\\10$1h/" count16.asm > "$src"
  grep -qE "^[[:space:]]*num[[:space:]]+dw[[:space:]]+0$1h" "$src" || return 2
  if [ "$2" = elf64 ]; then
    nasm -f elf64 -w-all "$src" -o "$BUILD/case16.o" && ld "$BUILD/case16.o" -o "$BUILD/case16" || return 3
  else
    nasm -f elf32 "$src" -o "$BUILD/case16.o" && ld -m elf_i386 "$BUILD/case16.o" -o "$BUILD/case16" || return 3
  fi
  timeout 5 "$BUILD/case16" > "$BUILD/out16.txt"
}

run_case16() {   # $1 = 4-digit hex input
  local v=$1 rc
  build_run16 "$v" elf32; rc=$?
  if [ $rc -ne 0 ]; then bad "count16 ${v}H: build/run failed (exit $rc)"; return; fi
  expected16 "$v" > "$BUILD/want16.txt"
  local want got
  want=$(python3 -c "n = bin(0x$v).count('1'); print(n, 16 - n)")
  got="$(sed -nE 's/^Ones  : ([0-9]+)$/\1/p' "$BUILD/out16.txt") $(sed -nE 's/^Zeros : ([0-9]+)$/\1/p' "$BUILD/out16.txt")"
  if [ "$got" != "$want" ]; then bad "count16 ${v}H: program says Ones/Zeros '$got', python3 says '$want'"; return; fi
  if ! cmp -s "$BUILD/out16.txt" "$BUILD/want16.txt"; then
    bad "count16 ${v}H: output differs from expected:"; diff "$BUILD/want16.txt" "$BUILD/out16.txt" | head -8; return
  fi
  ok
  printf '  ok  %sH -> Ones = %s, Zeros = %s\n' "$v" "${want% *}" "${want#* }"
}

echo "Running count16.asm (nasm -f elf32, ld -m elf_i386):"
for v in 0000 FFFF AAAA 5555 8000 0001 8001 00FF FF00 1234; do
  run_case16 "$v"
done
echo "  ... plus 40 seeded random values"
while read -r v; do
  run_case16 "$v" > /dev/null
done < <(python3 -c "
import random
random.seed(16)
for _ in range(40):
    print(f'{random.randrange(65536):04X}')
")

# ---------------------------------------------------------------------
# 3. count16.asm also assembles and runs as 64-bit code
#    (in case an online compiler uses nasm -f elf64)
# ---------------------------------------------------------------------
if build_run16 1234 elf64 && expected16 1234 | cmp -s - "$BUILD/out16.txt"; then
  ok; echo "PASS  count16: elf64 build gives the same output"
else
  bad "count16: elf64 build/run of 1234H"
fi

# ---------------------------------------------------------------------
# 4. The website's trace matches the assembly's per-step CF values,
#    and the output shown on index.html's 8086 tab is a real run
# ---------------------------------------------------------------------
build_run16 1234 elf32
sed -nE 's/^ ?([0-9]+)   \| ([01])  \| (ONES\+\+|ZEROS\+\+)$/\1 \2 \3/p' "$BUILD/out16.txt" > "$BUILD/asm_trace16.txt"
node test.js --trace16 4660 > "$BUILD/web_trace16.txt"
if [ "$(wc -l < "$BUILD/asm_trace16.txt")" -eq 16 ] && cmp -s "$BUILD/asm_trace16.txt" "$BUILD/web_trace16.txt"; then
  ok; echo "PASS  count16: website trace = assembly trace for 1234H (16 steps: CF, action)"
else
  bad "count16: website and assembly traces differ:"; diff "$BUILD/web_trace16.txt" "$BUILD/asm_trace16.txt"
fi
python3 -c "
import re, sys
html = open('index.html', encoding='utf-8').read()
m = re.search(r'<script type=\"text/plain\" id=\"src-output\">\n(.*?)</script>', html, re.S)
sys.exit(0 if m and m.group(1) == open('$BUILD/out16.txt').read() else 1)
" && { ok; echo "PASS  count16: output shown on the 8086 tab = real output of count16.asm"; } || bad "output block in index.html differs from a real run"

echo
echo "$pass checks passed, $fail failed"
[ "$fail" -eq 0 ]
