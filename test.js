#!/usr/bin/env node
// Tests for both lab problems. Run with: node test.js
//   Q15: the shift-and-add core in index.html
//   Q16: the bit-count core in bitcount.html
//
// The cores are NOT duplicated here: we pull the <script id="shiftadd-core">
// block straight out of index.html and the <script id="bitcount-core"> block
// out of bitcount.html, and execute each in a fresh VM context, so these
// tests run the exact code the browser runs.
//
// Helper modes used by test_asm.sh:
//   node test.js --trace <m> <q> <n>   Q15: prints "step q0 action P" per cycle
//   node test.js --trace16 <value>     Q16: prints "step cf action" per cycle

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

// The Q16 core, loaded the same way from bitcount.html.
const html16 = fs.readFileSync(path.join(__dirname, 'bitcount.html'), 'utf8');
const match16 = html16.match(/<script id="bitcount-core">([\s\S]*?)<\/script>/);
if (!match16) { console.error('FAIL: <script id="bitcount-core"> not found in bitcount.html'); process.exit(1); }
const ctx16 = vm.createContext({});
vm.runInContext(match16[1], ctx16, { filename: 'bitcount.html#bitcount-core' });
const BC = ctx16.BitCount;
if (!BC || typeof BC.count !== 'function') { console.error('FAIL: BitCount.count not exported'); process.exit(1); }

// ---------- --trace helper modes ----------
if (process.argv[2] === '--trace16') {
  const r = BC.count(Number(process.argv[3]));
  r.rows.slice(1).forEach((x) => console.log(`${x.step} ${x.cf} ${x.action}`));
  process.exit(0);
}
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

// =====================================================================
// Q16: count the 1s and 0s in AX (bitcount.html)
// =====================================================================

// Independent popcount, not using any core helper: Kernighan's x & (x - 1)
// clears the lowest 1 bit, so the number of rounds is the number of 1 bits.
function popcount(v) {
  let n = 0;
  for (let x = v; x !== 0; x &= x - 1) n++;
  return n;
}

// Checks every structural rule of one Q16 trace plus the final counts.
function verifyCount(v) {
  const tag = `count(${v.toString(16).toUpperCase().padStart(4, '0')}H)`;
  let r;
  try { r = BC.count(v); }
  catch (e) { return check(false, `${tag}: threw ${e.message}`); }

  const rows = r.rows;
  let ok = true;
  ok = check(rows.length === 17, `${tag}: expected 17 rows, got ${rows.length}`) && ok;
  ok = check(r.value === v && r.saved === v && big(r.bits) === BigInt(v) && r.bits.length === 16 &&
    parseInt(r.hex, 16) === v && r.hex.length === 4, `${tag}: value / saved copy / bits / hex`) && ok;

  const init = rows[0];
  ok = check(init.kind === 'init' && init.label === 'Initial' && init.step === 0 && init.ax === r.bits &&
    init.axVal === v && init.cf === '' && init.ones === 0 && init.zeros === 0 && init.count === 16,
    `${tag}: bad initial row`) && ok;

  for (let s = 1; s <= 16; s++) {
    const prev = rows[s - 1], row = rows[s];
    const out = prev.ax[15];                       // the bit SHR shifts out
    ok = check(row.ax.length === 16 && big(row.ax) === BigInt(row.axVal), `${tag} step ${s}: AX bits disagree with value`) && ok;
    // CF equals the bit shifted out.
    ok = check(row.cf === out && r.cfs[s - 1] === Number(out), `${tag} step ${s}: CF ${row.cf}, bit shifted out ${out}`) && ok;
    // AX halves: logical shift right, a 0 enters at the top.
    ok = check(row.ax === '0' + prev.ax.slice(0, 15) && row.axVal === Math.floor(prev.axVal / 2) && row.axVal === prev.axVal >>> 1,
      `${tag} step ${s}: AX did not halve`) && ok;
    // Exactly one counter changes, by exactly 1, and it is the right one.
    const dOnes = row.ones - prev.ones, dZeros = row.zeros - prev.zeros;
    ok = check(dOnes === (out === '1' ? 1 : 0) && dZeros === (out === '1' ? 0 : 1) && dOnes + dZeros === 1,
      `${tag} step ${s}: counters moved by ${dOnes}/${dZeros} for CF ${out}`) && ok;
    ok = check(row.kind === (out === '1' ? 'one' : 'zero') && row.action === (out === '1' ? 'ONES++' : 'ZEROS++') &&
      row.label === String(s) && row.step === s, `${tag} step ${s}: kind/action/label`) && ok;
    // Invariant: ONES + ZEROS = steps done; Count goes down by one.
    ok = check(row.ones + row.zeros === s && row.count === 16 - s && row.count === prev.count - 1,
      `${tag} step ${s}: ONES + ZEROS = ${row.ones + row.zeros}, Count = ${row.count}`) && ok;
    ok = check(row.why.indexOf(`CF = ${out}, so ${row.action}`) === 0, `${tag} step ${s}: reason text "${row.why}"`) && ok;
  }

  const last = rows[16], want = popcount(v);
  ok = check(last.count === 0 && last.axVal === 0 && /^0{16}$/.test(last.ax), `${tag}: final Count/AX not 0`) && ok;
  ok = check(r.ones === want && r.zeros === 16 - want && last.ones === r.ones && last.zeros === r.zeros,
    `${tag}: got ${r.ones} ones / ${r.zeros} zeros, expected ${want} / ${16 - want}`) && ok;
  ok = check(r.total === 16 && r.ones + r.zeros === 16, `${tag}: ONES + ZEROS = ${r.ones + r.zeros}`) && ok;
  // Second independent count: characters of the binary string.
  ok = check(v.toString(2).split('1').length - 1 === r.ones, `${tag}: toString(2) count disagrees`) && ok;
  return ok;
}

function section16(name, fn) {
  const before = failed;
  const t = Date.now();
  const runs = fn();
  console.log(`${failed === before ? 'PASS' : 'FAIL'}  ${name}${runs ? ` (${runs} values)` : ''}  [${Date.now() - t} ms]`);
}

section16('Q16 exhaustive: every 16-bit value against an independent popcount', () => {
  let k = 0;
  for (let v = 0; v <= 0xFFFF; v++) { verifyCount(v); k++; }
  return k;
});

section16('Q16 hand-worked trace: 1234H = 0001 0010 0011 0100', () => {
  //  Step       AX (after the shift)  CF   Action     ONES ZEROS Count
  const expected = [
    ['Initial', '0001001000110100', '',  'Save AX',  0,  0, 16],
    ['1',       '0000100100011010', '0', 'ZEROS++',  0,  1, 15],
    ['2',       '0000010010001101', '0', 'ZEROS++',  0,  2, 14],
    ['3',       '0000001001000110', '1', 'ONES++',   1,  2, 13],
    ['4',       '0000000100100011', '0', 'ZEROS++',  1,  3, 12],
    ['5',       '0000000010010001', '1', 'ONES++',   2,  3, 11],
    ['6',       '0000000001001000', '1', 'ONES++',   3,  3, 10],
    ['7',       '0000000000100100', '0', 'ZEROS++',  3,  4,  9],
    ['8',       '0000000000010010', '0', 'ZEROS++',  3,  5,  8],
    ['9',       '0000000000001001', '0', 'ZEROS++',  3,  6,  7],
    ['10',      '0000000000000100', '1', 'ONES++',   4,  6,  6],
    ['11',      '0000000000000010', '0', 'ZEROS++',  4,  7,  5],
    ['12',      '0000000000000001', '0', 'ZEROS++',  4,  8,  4],
    ['13',      '0000000000000000', '1', 'ONES++',   5,  8,  3],
    ['14',      '0000000000000000', '0', 'ZEROS++',  5,  9,  2],
    ['15',      '0000000000000000', '0', 'ZEROS++',  5, 10,  1],
    ['16',      '0000000000000000', '0', 'ZEROS++',  5, 11,  0],
  ];
  const r = BC.count(0x1234);
  check(r.rows.length === expected.length, `1234H: row count ${r.rows.length}`);
  expected.forEach((e, i) => {
    const x = r.rows[i];
    const got = [x.label, x.ax, x.cf, x.action, x.ones, x.zeros, x.count];
    check(JSON.stringify(got) === JSON.stringify(e), `1234H row ${i}: got ${JSON.stringify(got)}, want ${JSON.stringify(e)}`);
  });
  check(r.ones === 5 && r.zeros === 11 && r.hex === '1234' && r.saved === 0x1234, '1234H: 5 ones, 11 zeros, saved copy 1234H');
  check(r.rows[3].why === 'CF = 1, so ONES++ (ONES = 1). Count = 13.', `1234H step 3 reason: "${r.rows[3].why}"`);
});

section16('Q16 presets: 0000H, FFFFH, AAAAH, 8001H, 00FFH, 5555H, 8000H, 0001H', () => {
  const want = { 0x0000: [0, 16], 0xFFFF: [16, 0], 0xAAAA: [8, 8], 0x8001: [2, 14], 0x00FF: [8, 8],
    0x5555: [8, 8], 0x8000: [1, 15], 0x0001: [1, 15], 0xFF00: [8, 8] };
  for (const k of Object.keys(want)) {
    const r = BC.count(Number(k));
    check(r.ones === want[k][0] && r.zeros === want[k][1], `${r.hex}H gave ${r.ones}/${r.zeros}, want ${want[k]}`);
  }
  check(BC.count(0x8001).cfs.join('') === '1000000000000001', '8001H: CF sequence is 1, fourteen 0s, 1');
  check(BC.count(0xAAAA).cfs.join('') === '0101010101010101', 'AAAAH: CF alternates starting with 0');
});

section16('Q16 validation: parsing, range 0 to FFFFH, negatives', () => {
  const p = BC.parseNumber, v = BC.validate;
  check(p('4660', 'dec').v === 4660 && p(' 65535 ', 'dec').v === 65535, 'decimal parse');
  check(p('1234', 'hex').v === 0x1234 && p('1234h', 'hex').v === 0x1234 && p('0xAAAA', 'hex').v === 0xAAAA &&
    p('FFFFH', 'hex').v === 0xFFFF && p('ff', 'hex').v === 255, 'hex parse (plain, H suffix, 0x prefix, any case)');
  check(p('12a', 'dec').err && p('1.5', 'dec').err && p('G1', 'hex').err && p('', 'hex').err && p('0x', 'hex').err,
    'bad text rejected');
  check(p('-5', 'dec').v === -5, 'minus sign parsed so validate can explain it');
  check(v(0).ok && v(1).ok && v(0xFFFF).ok && v(0).error === '', '0 and FFFFH are valid');
  check(!v(0x10000).ok && /0000H to FFFFH/.test(v(0x10000).error) && !v(99999).ok, '10000H rejected with the range message');
  check(!v(-1).ok && /negative/.test(v(-1).error), 'negative rejected');
  check(!v(1.5).ok && !v(NaN).ok && !v('').ok && !v(null).ok && !v(undefined).ok && !v('12').ok && !v(Infinity).ok,
    'non-integers rejected');
  let threw = 0;
  for (const bad of [0x10000, -1, 1.5, NaN]) { try { BC.count(bad); } catch (e) { if (e.error) threw++; } }
  check(threw === 4, 'count throws on invalid input');
  check(BC.WIDTH === 16 && BC.MAX === 0xFFFF && BC.toBits(5, 16) === '0000000000000101' && BC.toHex(255, 4) === '00FF', 'helpers');
});

section16('Q16 8086 tab: embedded programs match count16.asm and count16_8086.asm', () => {
  for (const [id, file] of [['src-nasm', 'count16.asm'], ['src-masm', 'count16_8086.asm']]) {
    const m = html16.match(new RegExp(`<script type="text/plain" id="${id}">\\n([\\s\\S]*?)</script>`));
    const disk = fs.readFileSync(path.join(__dirname, file), 'utf8');
    check(m && m[1] === disk, `${id} in bitcount.html differs from ${file} (re-embed the file)`);
  }
});

section16('shared nav: both pages link to each other and mark the current page', () => {
  const nav = (h) => (h.match(/<nav class="pagenav"[\s\S]*?<\/nav>/) || [''])[0];
  const a = nav(html), b = nav(html16);
  check(/<a href="index\.html" aria-current="page">Q15 Shift-and-Add Multiply<\/a>/.test(a) &&
    /<a href="bitcount\.html">Q16 Count 1s and 0s in AX<\/a>/.test(a), 'index.html nav (Q15 current)');
  check(/<a href="index\.html">Q15 Shift-and-Add Multiply<\/a>/.test(b) &&
    /<a href="bitcount\.html" aria-current="page">Q16 Count 1s and 0s in AX<\/a>/.test(b), 'bitcount.html nav (Q16 current)');
  for (const [name, h] of [['index.html', html], ['bitcount.html', html16]]) {
    check(!/<script[^>]+src=|<link[^>]+href=|@import|url\((?!#)/i.test(h), `${name}: no external scripts, stylesheets or fonts`);
  }
});

console.log(`\n${passed} checks passed, ${failed} failed`);
if (failed) {
  console.log('\nFirst failures:\n  ' + failures.join('\n  '));
  process.exit(1);
}
