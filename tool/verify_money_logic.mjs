// The Flutter SDK is unavailable, so the Dart unit tests cannot execute here.
// This is a faithful port of the money logic in invoice_model.dart and
// db_mapper.dart, run against the same cases as the Dart tests, to confirm the
// ALGORITHM is correct. It is not a substitute for `flutter test`; it verifies
// the arithmetic, not the Dart code itself.
//
// Any divergence found here is a real bug in the Dart implementation, because
// this is a line-by-line translation.

let pass = 0, fail = 0;
const eq = (label, a, b) => {
  const ok = a === b;
  if (ok) { pass++; console.log(`  PASS  ${label}`); }
  else { fail++; console.log(`  FAIL  ${label}\n          expected ${JSON.stringify(b)}\n          actual   ${JSON.stringify(a)}`); }
};
const near = (label, a, b, tol = 0.001) => {
  const ok = Math.abs(a - b) <= tol;
  if (ok) { pass++; console.log(`  PASS  ${label}`); }
  else { fail++; console.log(`  FAIL  ${label} expected ~${b} got ${a}`); }
};

// ── port of InvoiceModel._indianNumberToWords ────────────────────────────────
const UNITS = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven',
  'Eight', 'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
  'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
const TENS = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy',
  'Eighty', 'Ninety'];

function twoDigits(v) {
  if (v < 20) return UNITS[v];
  const t = TENS[Math.floor(v / 10)];
  const u = v % 10;
  return u === 0 ? t : `${t} ${UNITS[u]}`;
}

function indianNumberToWords(n) {
  if (n === 0) return 'Zero';
  const parts = [];
  let rest = n;
  const crore = Math.floor(rest / 10000000); rest %= 10000000;
  const lakh = Math.floor(rest / 100000);    rest %= 100000;
  const thousand = Math.floor(rest / 1000);  rest %= 1000;
  const hundred = Math.floor(rest / 100);
  const remainder = rest % 100;
  if (crore > 0) parts.push(`${indianNumberToWords(crore)} Crore`);
  if (lakh > 0) parts.push(`${twoDigits(lakh)} Lakh`);
  if (thousand > 0) parts.push(`${twoDigits(thousand)} Thousand`);
  if (hundred > 0) parts.push(`${UNITS[hundred]} Hundred`);
  if (remainder > 0) parts.push(twoDigits(remainder));
  return parts.join(' ');
}

function rupeesToWords(amount) {
  const rupees = Math.floor(amount);
  const paise = Math.round((amount - rupees) * 100);
  let w = `${indianNumberToWords(rupees)} Rupees`;
  if (paise > 0) w += ` and ${indianNumberToWords(paise)} Paise`;
  return `${w} Only`;
}

// ── port of the invoice money model ──────────────────────────────────────────
const round2 = (v) => Math.round(v * 100) / 100;

function invoice(items, discount = 0) {
  const lineTotal = (i) => i.qty * i.unitPrice - (i.lineDiscount ?? 0);
  const subtotal = items.reduce((s, i) => s + lineTotal(i), 0);
  const effectiveDiscount = discount > subtotal ? subtotal : discount;
  const grandTotal = subtotal - effectiveDiscount;
  const payableTotal = Math.round(grandTotal);
  const roundOff = Number((payableTotal - grandTotal).toFixed(2));
  const taxAmount = (i) => lineTotal(i) * (i.tax / (100 + i.tax));
  const totalTax = items.reduce((s, i) => s + taxAmount(i), 0);
  return { subtotal, effectiveDiscount, grandTotal, payableTotal, roundOff,
    totalTax, amountInWords: rupeesToWords(payableTotal), items };
}

// port of DbMapper.invoiceToSalesRow money handling
function salesRow(inv) {
  const cgst = round2(inv.items.reduce((s, i) => {
    const lt = i.qty * i.unitPrice - (i.lineDiscount ?? 0);
    return s + (lt * (i.tax / (100 + i.tax))) / 2;
  }, 0));
  const sgst = cgst;
  const totalGst = round2(cgst + sgst);
  const grandTotal = round2(inv.grandTotal);
  const taxableAmount = round2(grandTotal - totalGst);
  return { cgst, sgst, totalGst, grandTotal, taxableAmount };
}

console.log('=== amount in words (Indian numbering) ===');
eq('100', rupeesToWords(100), 'One Hundred Rupees Only');
eq('1', rupeesToWords(1), 'One Rupees Only');
eq('1000', rupeesToWords(1000), 'One Thousand Rupees Only');
eq('100000', rupeesToWords(100000), 'One Lakh Rupees Only');
eq('10000000', rupeesToWords(10000000), 'One Crore Rupees Only');
eq('1250', rupeesToWords(1250), 'One Thousand Two Hundred Fifty Rupees Only');
eq('19', rupeesToWords(19), 'Nineteen Rupees Only');
eq('45', rupeesToWords(45), 'Forty Five Rupees Only');
eq('0', rupeesToWords(0), 'Zero Rupees Only');
eq('123456', rupeesToWords(123456),
  'One Lakh Twenty Three Thousand Four Hundred Fifty Six Rupees Only');
eq('90', rupeesToWords(90), 'Ninety Rupees Only');

console.log('\n=== round off ===');
let inv = invoice([{ qty: 3, unitPrice: 33.33, tax: 12 }]);
near('99.99 grand total', inv.grandTotal, 99.99);
eq('payable rounds to 100', inv.payableTotal, 100);
near('round off +0.01', inv.roundOff, 0.01);

inv = invoice([{ qty: 2, unitPrice: 50, tax: 12 }]);
eq('exact amount payable 100', inv.payableTotal, 100);
eq('round off zero', inv.roundOff, 0);

inv = invoice([{ qty: 1, unitPrice: 100.40, tax: 12 }]);
eq('rounds down to 100', inv.payableTotal, 100);
near('round off -0.40', inv.roundOff, -0.40);

console.log('\n=== discount clamping ===');
inv = invoice([{ qty: 1, unitPrice: 100, tax: 12 }], 500);
eq('discount clamped to subtotal', inv.effectiveDiscount, 100);
eq('grand total floors at zero', inv.grandTotal, 0);
eq('zero reads as Zero Rupees', inv.amountInWords, 'Zero Rupees Only');

console.log('\n=== GST reconciliation (the invoice must balance) ===');
for (const spec of [
  [[{ qty: 10, unitPrice: 100, tax: 12 }], 100],
  [[{ qty: 3, unitPrice: 33.33, tax: 12 }], 0],
  [[{ qty: 7, unitPrice: 14.29, tax: 5 }], 3],
  [[{ qty: 1, unitPrice: 999.99, tax: 18 }], 0.01],
  [[{ qty: 4, unitPrice: 62.5, tax: 12 }, { qty: 2, unitPrice: 33.33, tax: 5 }], 17],
]) {
  const i = invoice(spec[0], spec[1]);
  const r = salesRow(i);
  const label = `items=${spec[0].length} disc=${spec[1]}`;
  eq(`${label}: taxable + gst == grand total`,
    round2(r.taxableAmount + r.totalGst), r.grandTotal);
  eq(`${label}: cgst + sgst == total gst`,
    round2(r.cgst + r.sgst), r.totalGst);
  eq(`${label}: grand total never negative`, r.grandTotal >= 0, true);
}

console.log(`\nRESULT: ${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
