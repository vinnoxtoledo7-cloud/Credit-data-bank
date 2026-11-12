import {test} from 'node:test';import assert from 'node:assert/strict';
import {receiptLines,pdfBytes,csvCell} from '../shared/receipts.js';
test('unreconciled transfer cannot produce a completed receipt',()=>{const t={id:'test',created_at:'2026-11-12',amount:1,ledger:[]};assert(receiptLines(t).some(x=>x.includes('Pendente de conciliação')));assert(!receiptLines(t).some(x=>x.includes('Simulação confirmada')));});
test('PDF has valid byte offsets, streams and multiple pages',()=>{const bytes=pdfBytes(Array.from({length:100},(_,i)=>`Simulação ${i}: R$ 12,34 (teste) \\`));const text=Buffer.from(bytes).toString('latin1');assert.match(text,/\/Count 3/);const xref=Number(text.match(/startxref\n(\d+)/)[1]);assert.equal(text.slice(xref,xref+4),'xref');for(const m of text.matchAll(/(\d{10}) 00000 n/g)){assert.match(text.slice(Number(m[1])),/^\d+ 0 obj/);}});
test('CSV escapes formulas and quotes',()=>{assert.equal(csvCell('=1+1'),'"\'=1+1"');assert.equal(csvCell('a"b'),'"a""b"');});
