#!/usr/bin/env node
// Tests for the bit-count core in index.html. Run with: node test.js
//
// The core is NOT duplicated here: we pull the <script id="bitcount-core">
// block straight out of index.html and execute it in a fresh VM context, so
// these tests run the exact code the browser runs.
//
// Helper mode used by test_asm.sh:
//   node test.js --trace16 <value>     prints "step cf action" per cycle

'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const html16 = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
const match16 = html16.match(/<script id="bitcount-core">([\s\S]*?)<\/script>/);
if (!match16) { console.error('FAIL: <script id="bitcount-core"> not found in index.html'); process.exit(1); }
const ctx16 = vm.createContext({});
vm.runInContext(match16[1], ctx16, { filename: 'index.html#bitcount-core' });
const BC = ctx16.BitCount;
if (!BC || typeof BC.count !== 'function') { console.error('FAIL: BitCount.count not exported'); process.exit(1); }

// ---------- --trace16 helper mode ----------
if (process.argv[2] === '--trace16') {
  const r = BC.count(Number(process.argv[3]));
  r.rows.slice(1).forEach((x) => console.log(`${x.step} ${x.cf} ${x.action}`));
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

// Independent popcount, not using any core helper: Kernighan's x & (x - 1)
// clears the lowest 1 bit, so the number of rounds is the number of 1 bits.
function popcount(v) {
  let n = 0;
  for (let x = v; x !== 0; x &= x - 1) n++;
  return n;
}

// Checks every structural rule of one trace plus the final counts.
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

section16('exhaustive: every 16-bit value against an independent popcount', () => {
  let k = 0;
  for (let v = 0; v <= 0xFFFF; v++) { verifyCount(v); k++; }
  return k;
});

section16('hand-worked trace: 1234H = 0001 0010 0011 0100', () => {
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

section16('presets: 0000H, FFFFH, AAAAH, 8001H, 00FFH, 5555H, 8000H, 0001H', () => {
  const want = { 0x0000: [0, 16], 0xFFFF: [16, 0], 0xAAAA: [8, 8], 0x8001: [2, 14], 0x00FF: [8, 8],
    0x5555: [8, 8], 0x8000: [1, 15], 0x0001: [1, 15], 0xFF00: [8, 8] };
  for (const k of Object.keys(want)) {
    const r = BC.count(Number(k));
    check(r.ones === want[k][0] && r.zeros === want[k][1], `${r.hex}H gave ${r.ones}/${r.zeros}, want ${want[k]}`);
  }
  check(BC.count(0x8001).cfs.join('') === '1000000000000001', '8001H: CF sequence is 1, fourteen 0s, 1');
  check(BC.count(0xAAAA).cfs.join('') === '0101010101010101', 'AAAAH: CF alternates starting with 0');
});

section16('validation: parsing, range 0 to FFFFH, negatives', () => {
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

section16('8086 tab: embedded programs match count16.asm and count16_8086.asm', () => {
  for (const [id, file] of [['src-nasm', 'count16.asm'], ['src-masm', 'count16_8086.asm']]) {
    const m = html16.match(new RegExp(`<script type="text/plain" id="${id}">\\n([\\s\\S]*?)</script>`));
    const disk = fs.readFileSync(path.join(__dirname, file), 'utf8');
    check(m && m[1] === disk, `${id} in index.html differs from ${file} (re-embed the file)`);
  }
});

section16('page: loads nothing external', () => {
  check(!/<script[^>]+src=|<link[^>]+href=|@import|url\((?!#)/i.test(html16), 'index.html: no external scripts, stylesheets or fonts');
});

console.log(`\n${passed} checks passed, ${failed} failed`);
if (failed) {
  console.log('\nFirst failures:\n  ' + failures.join('\n  '));
  process.exit(1);
}
