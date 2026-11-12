export const disclaimer='COMPROVANTE DE SIMULAÇÃO. SEM VALOR BANCÁRIO.';
export function receiptLines(t){
 const ok=t.reconciled===true;
 return ['CREDIT DATA BANK',disclaimer,`Identificador: ${t.id}`,`Data: ${new Date(t.created_at).toLocaleString('pt-BR',{timeZone:'America/Sao_Paulo'})} (Brasília)`,`Origem: ${t.source_name}`,`Conta de origem: ${t.source_account_id}`,`Destino: ${t.destination_name}`,`Conta de destino: ${t.destination_account_id}`,`Valor fictício: ${Number(t.amount).toLocaleString('pt-BR',{style:'currency',currency:'BRL'})}`,`Descrição: ${t.description}`,`Status: ${ok?'Simulação confirmada':'Pendente de conciliação'}`,`Conciliação: ${ok?'Um débito e um crédito conferidos':'Divergência; não considerar concluída'}`,...(t.ledger||[]).map(l=>`Lançamento: ${l.id} | ${l.amount}`)];
}
// Small, dependency-free PDF writer. WinAnsi Helvetica, wrapped text and pagination.
export function pdfBytes(lines){
 const clean=s=>String(s).replace(/[–—]/g,'-').replace(/[^\x20-\xFF]/g,'?');
 const wrapped=lines.flatMap(line=>{const s=clean(line);return s.match(/.{1,85}(?:\s|$)|.{1,85}/g)||[''];});
 const pages=[];for(let i=0;i<wrapped.length;i+=46)pages.push(wrapped.slice(i,i+46));
 const objects=['<< /Type /Catalog /Pages 2 0 R >>','', '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>'];
 const pageIds=[];
 for(const page of pages){const id=objects.length+1;pageIds.push(id);const escape=s=>s.replace(/([\\()])/g,'\\$1');const content='BT /F1 11 Tf 48 790 Td 15 TL\n'+page.map((s,i)=>(i?'T* ':'')+'('+escape(s.trim())+') Tj').join('\n')+'\nET';objects.push(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 3 0 R >> >> /Contents ${id+1} 0 R >>`,`<< /Length ${content.length} >>\nstream\n${content}\nendstream`);}
 objects[1]=`<< /Type /Pages /Count ${pages.length} /Kids [${pageIds.map(i=>i+' 0 R').join(' ')}] >>`;
 let out='%PDF-1.4\n',offsets=[0];objects.forEach((o,i)=>{offsets.push(out.length);out+=`${i+1} 0 obj\n${o}\nendobj\n`;});const xref=out.length;out+=`xref\n0 ${objects.length+1}\n0000000000 65535 f \n`+offsets.slice(1).map(n=>String(n).padStart(10,'0')+' 00000 n \n').join('')+`trailer\n<< /Size ${objects.length+1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;return Uint8Array.from(out,c=>c.charCodeAt(0));
}
export function downloadPDF(lines,name){download(pdfBytes(lines),'application/pdf',name+'.pdf');}
export function download(data,type,name){const url=URL.createObjectURL(new Blob([data],{type})),a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
export function csvCell(value){const s=String(value??'');return '"'+(/^[=+\-@\t\r]/.test(s)?"'":'')+s.replaceAll('"','""')+'"';}
