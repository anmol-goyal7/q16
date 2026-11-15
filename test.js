#!/usr/bin/env node
// Tests for the shift-and-add core. Run with: node test.js
//
// The core is NOT duplicated here: we pull the <script id="shiftadd-core">
// block straight out of index.html and execute it in a fresh VM context, so
// these tests run the exact code the browser runs.
//
// Helper mode used by test_asm.sh:
//   node test.js --trace <m> <q> <n>   prints "step q0 action P" per cycle

'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const html = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
const match = html.match(/<script id="shiftadd-core">([\s\S]*?)<\/script>/);
if (!match) { console.error('FAIL: <script id="shiftadd-core"> not found in index.html'); process.exit(1); }
const ctx = vm.createContext({});
vm.runInContext(match[1], ctx, { filename: 'index.html#shiftadd-core' });
const SA = ctx.ShiftAdd;
if (!SA || typeof SA.multiply !== 'function') { console.error('FAIL: ShiftAdd.multiply not exported'); process.exit(1); }

// ---------- --trace helper mode ----------
if (process.argv[2] === '--trace') {
  const [m, q, n] = process.argv.slice(3).map(Number);
  const r = SA.multiply(m, q, n);
  r.rows.filter((x) => x.kind === 'add' || x.kind === 'skip').forEach((x) => {
    console.log(`${x.cycle} ${x.q0} ${x.kind === 'add' ? 'ADD' : 'SKIP'} ${SA.toHex(x.pVal, r.width / 4)}`);
  });
  process.exit(0);
}

let passed = 0, failed = 0;
const failures = [];
function check(cond, msg) {
  if (cond) { passed++; return true; }
  failed++;
  if (failures.length < 25) failures.push(msg);
  return false;
}

// Independent unsigned decode as a BigInt, not using any core helper.
function big(bits) {
  let v = 0n;
  for (const b of bits) v = v * 2n + (b === '1' ? 1n : 0n);
  return v;
}

// Checks every structural rule of the trace plus the final product.
function verifyRun(m, q, n) {
  const tag = `${m} x ${q} @${n}`;
  let r;
  try { r = SA.multiply(m, q, n); }
  catch (e) { return check(false, `${tag}: threw ${e.message}`); }

  const rows = r.rows, w = 2 * n;
  let ok = true;
  ok = check(r.width === w, `${tag}: product width ${r.width}`) && ok;
  ok = check(rows.length === 2 * n + 1, `${tag}: expected ${2 * n + 1} rows, got ${rows.length}`) && ok;
  ok = check(big(r.Mbits) === BigInt(m) && big(r.Qbits) === BigInt(q) && r.Mbits.length === n && r.Qbits.length === n,
    `${tag}: setup bits`) && ok;

  for (const row of rows) {
    ok = check(row.M.length === w && row.P.length === w && row.Q.length === n, `${tag} row ${row.label}: register widths`) && ok;
    ok = check(big(row.M) === BigInt(row.mVal) && big(row.Q) === BigInt(row.qVal) && big(row.P) === BigInt(row.pVal),
      `${tag} row ${row.label}: bits disagree with values`) && ok;
  }

  const init = rows[0];
  ok = check(init.kind === 'init' && init.label === 'Initial' && big(init.P) === 0n && big(init.M) === BigInt(m) &&
    big(init.Q) === BigInt(q) && init.count === n, `${tag}: bad initial row`) && ok;

  for (let c = 1; c <= n; c++) {
    const prev = rows[2 * c - 2], op = rows[2 * c - 1], sh = rows[2 * c];
    const q0 = prev.Q[n - 1];
    // Add happens exactly when Q0 = 1.
    ok = check(op.q0 === q0 && op.kind === (q0 === '1' ? 'add' : 'skip') &&
      op.action === (q0 === '1' ? 'Add M' : 'No add') && op.label === String(c),
      `${tag} cycle ${c}: Q0 ${q0} gave ${op.kind}`) && ok;
    // P changes by exactly M or 0; M, Q, Count unchanged on the add row.
    const delta = q0 === '1' ? big(prev.M) : 0n;
    ok = check(big(op.P) === big(prev.P) + delta && BigInt(op.added) === delta, `${tag} cycle ${c}: P += ${delta} wrong`) && ok;
    ok = check(op.M === prev.M && op.Q === prev.Q && op.count === prev.count, `${tag} cycle ${c}: add row changed M/Q/Count`) && ok;
    // Shift row: M doubles (no bit lost off the top), Q halves (logical), P same, Count - 1.
    ok = check(sh.kind === 'shift' && sh.action === 'Shift M left, Q right', `${tag} cycle ${c}: shift row kind`) && ok;
    ok = check(op.M[0] === '0' && sh.M === op.M.slice(1) + '0' && big(sh.M) === 2n * big(op.M), `${tag} cycle ${c}: M did not double`) && ok;
    ok = check(sh.Q === '0' + op.Q.slice(0, -1) && big(sh.Q) === big(op.Q) / 2n, `${tag} cycle ${c}: Q did not halve`) && ok;
    ok = check(sh.P === op.P && sh.count === op.count - 1 && sh.count === n - c, `${tag} cycle ${c}: P/Count on shift row`) && ok;
  }

  const last = rows[rows.length - 1];
  const want = BigInt(m) * BigInt(q);
  ok = check(last.count === 0 && /^0+$/.test(last.Q), `${tag}: final Count/Q not 0`) && ok;
  ok = check(r.product.bits === last.P && r.product.bits.length === w, `${tag}: product bits`) && ok;
  ok = check(big(r.product.bits) === want && BigInt(r.product.value) === want, `${tag}: product ${r.product.value}, expected ${want}`) && ok;
  ok = check(BigInt('0x' + r.product.hex) === want && r.product.hex.length === w / 4, `${tag}: product hex ${r.product.hex}`) && ok;
  ok = check(want < 1n << BigInt(w), `${tag}: product does not fit in 2n bits`) && ok;
  ok = check(r.partials.length === n && BigInt(r.partials[n - 1]) === want, `${tag}: partials`) && ok;
  return ok;
}

function section(name, fn) {
  const before = failed;
  const t = Date.now();
  const runs = fn();
  console.log(`${failed === before ? 'PASS' : 'FAIL'}  ${name}${runs ? ` (${runs} products)` : ''}  [${Date.now() - t} ms]`);
}

// ---------- exhaustive 4 and 8 bit ----------
for (const n of [4, 8]) {
  section(`exhaustive ${n}-bit: every (M, Q) pair`, () => {
    const max = 2 ** n - 1;
    let k = 0;
    for (let m = 0; m <= max; m++) for (let q = 0; q <= max; q++) { verifyRun(m, q, n); k++; }
    return k;
  });
}

// ---------- 16 bit: random sample + every extreme combination ----------
section('16-bit: 50,000 random pairs + all extreme combinations', () => {
  let seed = 0x5AFE15; // deterministic LCG so failures are reproducible
  const rnd = () => (seed = (Math.imul(seed, 1103515245) + 12345) >>> 0) / 2 ** 32;
  let k = 0;
  for (let i = 0; i < 50000; i++) {
    verifyRun(Math.floor(rnd() * 65536), Math.floor(rnd() * 65536), 16); k++;
  }
  const edges = new Set([0, 1, 65534, 65535]);
  for (let b = 0; b < 16; b++) edges.add(2 ** b);
  for (const m of edges) for (const q of edges) { verifyRun(m, q, 16); k++; }
  return k;
});

// ---------- hand-worked trace ----------
section('hand-worked trace: 13 x 11 at 4 bits', () => {
  //  Step       Q0   Action                   M (2n bits)  Q       P (2n bits)  Count
  const expected = [
    ['Initial', '',  'Initialise',            '00001101', '1011', '00000000', 4],
    ['1',       '1', 'Add M',                 '00001101', '1011', '00001101', 4],
    ['',        '',  'Shift M left, Q right', '00011010', '0101', '00001101', 3],
    ['2',       '1', 'Add M',                 '00011010', '0101', '00100111', 3],
    ['',        '',  'Shift M left, Q right', '00110100', '0010', '00100111', 2],
    ['3',       '0', 'No add',                '00110100', '0010', '00100111', 2],
    ['',        '',  'Shift M left, Q right', '01101000', '0001', '00100111', 1],
    ['4',       '1', 'Add M',                 '01101000', '0001', '10001111', 1],
    ['',        '',  'Shift M left, Q right', '11010000', '0000', '10001111', 0],
  ];
  const r = SA.multiply(13, 11, 4);
  check(r.rows.length === expected.length, `13 x 11: row count ${r.rows.length}`);
  expected.forEach((e, i) => {
    const x = r.rows[i];
    const got = [x.label, x.q0, x.action, x.M, x.Q, x.P, x.count];
    check(JSON.stringify(got) === JSON.stringify(e), `13 x 11 row ${i}: got ${JSON.stringify(got)}, want ${JSON.stringify(e)}`);
  });
  check(r.Mbits === '1101' && r.Qbits === '1011', '13 x 11: setup bits 1101 / 1011');
  check(r.product.bits === '10001111' && r.product.value === 143 && r.product.hex === '8F', '13 x 11: product 10001111 = 143 = 8FH');
  check(JSON.stringify(r.partials) === '[13,39,39,143]', '13 x 11: partial products 13, 39, 39, 143');
});

section('16-bit default: 1234H x 5678H = 06260060H', () => {
  const r = SA.multiply(0x1234, 0x5678, 16);
  check(r.product.hex === '06260060' && r.product.value === 103153760, `1234H x 5678H gave ${r.product.hex}`);
  const r2 = SA.multiply(0xFFFF, 0xFFFF, 16);
  check(r2.product.hex === 'FFFE0001', `FFFFH x FFFFH gave ${r2.product.hex}`);
});

// ---------- input parsing and validation ----------
section('validation: parsing, ranges, negatives, widths', () => {
  const p = SA.parseNumber, v = SA.validate;
  check(p('13', 'dec').v === 13 && p(' 255 ', 'dec').v === 255, 'decimal parse');
  check(p('D', 'hex').v === 13 && p('1234h', 'hex').v === 0x1234 && p('0x5678', 'hex').v === 0x5678 &&
    p('FFFFH', 'hex').v === 0xFFFF && p('ff', 'hex').v === 255, 'hex parse (plain, H suffix, 0x prefix, any case)');
  check(p('12a', 'dec').err && p('1.5', 'dec').err && p('G1', 'hex').err && p('', 'dec').err && p('0x', 'hex').err,
    'bad text rejected');
  check(p('-5', 'dec').v === -5 && p('-A', 'hex').v === -10, 'minus sign parsed so validate can explain it');
  check(v(15, 15, 4).ok && v(0, 0, 4).ok, '0..15 valid at 4 bits');
  check(!v(16, 1, 4).ok && /between 0 and 15/.test(v(16, 1, 4).errors.m), '16 rejected at 4 bits with range message');
  check(v(255, 255, 8).ok && !v(1, 256, 8).ok && v(1, 256, 8).errors.q, '8-bit range 0..255');
  check(v(65535, 65535, 16).ok && !v(65536, 0, 16).ok && /FFFFH/.test(v(65536, 0, 16).errors.m), '16-bit range 0..65535');
  const neg = v(-5, 3, 8);
  check(!neg.ok && /unsigned only - see Booth's for signed/.test(neg.errors.m), 'negative rejected with the Booth note');
  check(!v(1.5, 2, 4).ok && !v(NaN, 2, 4).ok && !v('', 2, 4).ok, 'non-integers rejected');
  check(!v(1, 1, 5).ok && v(1, 1, 5).errors.n && !v(1, 1, 32).ok, 'widths other than 4, 8, 16 rejected');
  let threw = false;
  try { SA.multiply(16, 1, 4); } catch (e) { threw = !!e.errors; }
  check(threw, 'multiply throws on invalid input');
});

// ---------- the assembly shown on the 8086 tab is the real file ----------
section('8086 tab: embedded programs match mul16.asm and mul16_8086.asm', () => {
  for (const [id, file] of [['src-nasm', 'mul16.asm'], ['src-masm', 'mul16_8086.asm']]) {
    const m = html.match(new RegExp(`<script type="text/plain" id="${id}">\\n([\\s\\S]*?)</script>`));
    const disk = fs.readFileSync(path.join(__dirname, file), 'utf8');
    check(m && m[1] === disk, `${id} in index.html differs from ${file} (re-embed the file)`);
  }
});

console.log(`\n${passed} checks passed, ${failed} failed`);
if (failed) {
  console.log('\nFirst failures:\n  ' + failures.join('\n  '));
  process.exit(1);
}
