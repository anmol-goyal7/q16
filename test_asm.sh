#!/usr/bin/env bash
# Tests for the assembly programs. Run with: ./test_asm.sh
# Needs: nasm, ld (binutils), python3, node.
#
# For every test case the two inputs are substituted into a temporary copy
# of mul16.asm, which is assembled (nasm -f elf32), linked (ld -m elf_i386)
# and run. Its whole output is compared with the output python3 expects,
# and the Product line is parsed and checked against python's a * b.

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

# ---------------------------------------------------------------------
# 1. No MUL / IMUL instruction anywhere (comments and strings removed)
# ---------------------------------------------------------------------
strip_asm() { sed -e 's/;.*//' -e "s/'[^']*'//g" -e 's/"[^"]*"//g' "$1"; }
has_mul()   { strip_asm "$1" | grep -qiE '(^|[^a-z0-9_.@?$])i?mul([^a-z0-9_]|$)'; }

# Self-test of the checker, so a broken regex cannot pass silently.
printf '  mul bx\n'               > "$BUILD/t1.asm"
printf 'L1: IMUL CX ; x\n'        > "$BUILD/t2.asm"
printf 'mul_loop: add ax, bx\n'   > "$BUILD/t3.asm"
printf 'm db "no MUL" ; MUL\n'    > "$BUILD/t4.asm"
if has_mul "$BUILD/t1.asm" && has_mul "$BUILD/t2.asm" && ! has_mul "$BUILD/t3.asm" && ! has_mul "$BUILD/t4.asm"; then
  ok
else
  bad "MUL detector self-test"
fi
for f in mul16.asm mul16_8086.asm; do
  if has_mul "$f"; then bad "$f uses MUL/IMUL:"; strip_asm "$f" | grep -niE '(^|[^a-z0-9_.@?$])i?mul([^a-z0-9_]|$)'; else ok; fi
done
echo "PASS  no MUL / IMUL instruction in mul16.asm or mul16_8086.asm"

# ---------------------------------------------------------------------
# 2. The MASM program runs the same algorithm instructions as the tested
#    NASM program (from loading the inputs to the end of the loop).
# ---------------------------------------------------------------------
algo() {
  strip_asm "$1" | tr 'A-Z' 'a-z' | tr -d '[]' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//; s/ ?, ?/,/g' |
    awk '/^mov si,num1$/ {on=1} on && $0 != "" && $1 != "call" {print} /^jnz next_bit$/ {on=0}'
}
algo mul16.asm > "$BUILD/algo_nasm.txt"
algo mul16_8086.asm > "$BUILD/algo_masm.txt"
if [ "$(wc -l < "$BUILD/algo_nasm.txt")" -ge 15 ] && cmp -s "$BUILD/algo_nasm.txt" "$BUILD/algo_masm.txt"; then
  ok; echo "PASS  MASM algorithm block is identical to the NASM one ($(wc -l < "$BUILD/algo_nasm.txt") lines)"
else
  bad "MASM and NASM algorithm blocks differ:"; diff "$BUILD/algo_nasm.txt" "$BUILD/algo_masm.txt"
fi
masm_ok=1
for pat in '^\.MODEL SMALL' '^\.STACK' '^\.DATA' '^\.CODE' 'MOV AX, @DATA' 'MOV DS, AX' 'PROD_LO DW' 'PROD_HI DW' \
           'MOV PROD_LO, AX' 'MOV PROD_HI, DX' 'MOV AH, 02H' 'MOV AH, 4CH' '^END MAIN'; do
  grep -qE "$pat" mul16_8086.asm || { bad "mul16_8086.asm is missing: $pat"; masm_ok=0; }
done
[ $masm_ok = 1 ] && { ok; echo "PASS  mul16_8086.asm has the lab-manual structure (.MODEL SMALL ... MOV AH,4CH / INT 21H)"; }

# ---------------------------------------------------------------------
# 3. Build and run mul16.asm for each case
# ---------------------------------------------------------------------
expected() {   # exact output mul16.asm must print for inputs $1 $2 (hex)
  python3 - "$1" "$2" <<'PY'
import sys
a, b = int(sys.argv[1], 16), int(sys.argv[2], 16)
out = ["Shift-and-Add Multiplication (no MUL)",
       f"Multiplicand : {a:04X}H ({a})",
       f"Multiplier   : {b:04X}H ({b})",
       "Step | Q0 | Action | Partial Product"]
p = 0
for i in range(16):
    q0 = (b >> i) & 1
    if q0:
        p += a << i
    out.append(f"{i + 1:2d}   | {q0}  | {'ADD M ' if q0 else 'SKIP  '} | {p:08X}H")
out.append(f"Product      : {a * b:08X}H ({a * b})")
print("\n".join(out))
PY
}

build_run() {   # $1 $2 = hex inputs; $3 = format (elf32|elf64). Output -> $BUILD/out.txt
  local src="$BUILD/case.asm"
  sed -E -e "s/^([[:space:]]*num1[[:space:]]+dw[[:space:]]+)[0-9A-Fa-f]+h/\\10$1h/" \
         -e "s/^([[:space:]]*num2[[:space:]]+dw[[:space:]]+)[0-9A-Fa-f]+h/\\10$2h/" mul16.asm > "$src"
  grep -qE "num1[[:space:]]+dw[[:space:]]+0$1h" "$src" && grep -qE "num2[[:space:]]+dw[[:space:]]+0$2h" "$src" || return 2
  if [ "$3" = elf64 ]; then
    nasm -f elf64 -w-all "$src" -o "$BUILD/case.o" && ld "$BUILD/case.o" -o "$BUILD/case" || return 3
  else
    nasm -f elf32 "$src" -o "$BUILD/case.o" && ld -m elf_i386 "$BUILD/case.o" -o "$BUILD/case" || return 3
  fi
  timeout 5 "$BUILD/case" > "$BUILD/out.txt"
}

run_case() {   # $1 $2 = 4-digit hex inputs
  local a=$1 b=$2 rc
  build_run "$a" "$b" elf32; rc=$?
  if [ $rc -ne 0 ]; then bad "${a}H x ${b}H: build/run failed (exit $rc)"; return; fi
  expected "$a" "$b" > "$BUILD/want.txt"
  local want got
  want=$(python3 -c "print(f'{0x$a * 0x$b:08X} {0x$a * 0x$b}')")
  got=$(sed -nE 's/^Product      : ([0-9A-F]{8})H \(([0-9]+)\)$/\1 \2/p' "$BUILD/out.txt")
  if [ "$got" != "$want" ]; then bad "${a}H x ${b}H: Product line says '$got', python3 says '$want'"; return; fi
  if ! cmp -s "$BUILD/out.txt" "$BUILD/want.txt"; then
    bad "${a}H x ${b}H: output differs from expected:"; diff "$BUILD/want.txt" "$BUILD/out.txt" | head -8; return
  fi
  ok
  printf '  ok  %sH x %sH = %sH (%s)\n' "$a" "$b" "${want% *}" "${want#* }"
}

echo "Running mul16.asm (nasm -f elf32, ld -m elf_i386):"
for c in 0000:0000 0000:1234 0001:0001 0001:FFFF FFFF:FFFF 8000:0002 00FF:00FF 1234:5678 000D:000B; do
  run_case "${c%:*}" "${c#*:}"
done
echo "  ... plus 40 seeded random pairs"
while read -r a b; do
  run_case "$a" "$b" > /dev/null
done < <(python3 -c "
import random
random.seed(15)
for _ in range(40):
    print(f'{random.randrange(65536):04X} {random.randrange(65536):04X}')
")

# ---------------------------------------------------------------------
# 4. The same program also assembles and runs as 64-bit code
#    (in case an online compiler uses nasm -f elf64)
# ---------------------------------------------------------------------
if build_run 1234 5678 elf64 && expected 1234 5678 | cmp -s - "$BUILD/out.txt"; then
  ok; echo "PASS  elf64 build gives the same output"
else
  bad "elf64 build/run of 1234H x 5678H"
fi

# ---------------------------------------------------------------------
# 5. The website's trace matches the assembly's per-step partial products
# ---------------------------------------------------------------------
build_run 1234 5678 elf32
sed -nE 's/^ ?([0-9]+)   \| ([01])  \| (ADD M|SKIP) +\| ([0-9A-F]{8})H$/\1 \2 \3 \4/p' "$BUILD/out.txt" | sed 's/ADD M/ADD/' > "$BUILD/asm_trace.txt"
node test.js --trace 4660 22136 16 > "$BUILD/web_trace.txt"
if [ "$(wc -l < "$BUILD/asm_trace.txt")" -eq 16 ] && cmp -s "$BUILD/asm_trace.txt" "$BUILD/web_trace.txt"; then
  ok; echo "PASS  website trace = assembly trace for 1234H x 5678H (16 steps: Q0, action, partial product)"
else
  bad "website and assembly traces differ:"; diff "$BUILD/web_trace.txt" "$BUILD/asm_trace.txt"
fi

# ---------------------------------------------------------------------
# 6. The expected output shown on the website's 8086 tab is a real run
# ---------------------------------------------------------------------
build_run 1234 5678 elf32
python3 -c "
import re, sys
html = open('index.html', encoding='utf-8').read()
m = re.search(r'<script type=\"text/plain\" id=\"src-output\">\n(.*?)</script>', html, re.S)
sys.exit(0 if m and m.group(1) == open('$BUILD/out.txt').read() else 1)
" && { ok; echo "PASS  output shown on the 8086 tab = real output of mul16.asm"; } || bad "output block in index.html differs from a real run"

echo
echo "$pass checks passed, $fail failed"
[ "$fail" -eq 0 ]
