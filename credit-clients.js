import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.10';
const db = createClient('https://jruspbiljejmknjvnesd.supabase.co', 'sb_publishable_02sp2eGomD108oDM1Be8yg_-z7URJmT');
const el = id => document.getElementById(id);
const money = n => Number(n).toLocaleString('pt-BR', {style:'currency',currency:'BRL'});
const date = s => new Date(s).toLocaleString('pt-BR', {timeZone:'America/Sao_Paulo'}) + ' (Brasília)';
const message = text => {el('msg').textContent = text;};
let user, accounts = [], beneficiaries = [], offset = 0, receiptText = '', receiptId = '', busy = false;
function p(parent, text) { const node = document.createElement('p'); node.textContent = text; parent.append(node); }
function option(select, value, text) { const node = document.createElement('option'); node.value=value; node.textContent=text; select.append(node); }
async function checked(query) { const {data,error} = await query; if(error) throw new Error(error.message); if(data?.error) throw new Error(data.error); return data; }
async function run(action) { try {await action();} catch(e) {message('Não foi possível concluir: ' + e.message);} }
async function init() {
  const {data,error} = await db.auth.getUser(); user = data?.user;
  el('login').hidden=!!user; el('work').hidden=!user; el('logout').hidden=!user;
  if(user) await refresh(); else if(error && error.name!=='AuthSessionMissingError') message('Entre novamente para continuar.');
}
async function loadAccounts() {
  accounts = await checked(db.from('credit_accounts').select('id,display_name,account_type').eq('owner_id',user.id).eq('status','sandbox').order('created_at'));
  const balances = await checked(db.rpc('credit_account_balances'));
  const old=el('source').value; el('source').replaceChildren(); option(el('source'),'','Selecione a origem');
  for(const a of accounts) option(el('source'),a.id,`${a.account_type} · ${a.display_name} · ${money(balances.find(b=>b.account_id===a.id)?.balance||0)}`);
  if(accounts.some(a=>a.id===old)) el('source').value=old;
}
async function loadBeneficiaries() {
  beneficiaries = await checked(db.from('credit_beneficiaries').select('id,account_id,nickname,recipient_name').eq('owner_id',user.id).order('created_at'));
  const old=el('beneficiary').value; el('beneficiary').replaceChildren(); option(el('beneficiary'),'','Selecione o beneficiário'); el('beneficiaries').replaceChildren();
  for(const b of beneficiaries) {
    option(el('beneficiary'),b.id,`${b.nickname} · ${b.recipient_name}`);
    const row=document.createElement('div'); row.className='row'; p(row,`${b.nickname} · Titular: ${b.recipient_name}`); p(row,`Conta: ${b.account_id}`);
    const remove=document.createElement('button'); remove.textContent='Remover'; remove.onclick=()=>run(async()=>{
      if(!confirm('Remover este beneficiário? O histórico será preservado.'))return;
      remove.disabled=true;
      try {await checked(db.rpc('credit_beneficiary_remove',{p_id:b.id}));await loadBeneficiaries();await loadAudit();} finally{remove.disabled=false;}
    }); row.append(remove); el('beneficiaries').append(row);
  }
  if(beneficiaries.some(b=>b.id===old))el('beneficiary').value=old;
  if(!beneficiaries.length)p(el('beneficiaries'),'Nenhum beneficiário cadastrado.');
}
async function history(reset=true) {
  if(reset){offset=0;el('history').replaceChildren();}
  let q=db.from('credit_client_transfers').select('id,sender_id,source_name,destination_name,amount,description,created_at').order('created_at',{ascending:false}).order('id',{ascending:false}).range(offset,offset+24);
  if(el('direction').value==='sent')q=q.eq('sender_id',user.id);
  if(el('direction').value==='received')q=q.eq('recipient_id',user.id);
  const rows=await checked(q);
  for(const t of rows){const row=document.createElement('div');row.className='row';p(row,`${t.sender_id===user.id?'Enviada':'Recebida'} · ${money(t.amount)} · ${date(t.created_at)}`);p(row,`${t.source_name} → ${t.destination_name} · ${t.description}`);const b=document.createElement('button');b.textContent='Ver comprovante';b.onclick=()=>run(()=>receipt(t.id));row.append(b);el('history').append(row);}
  if(!offset&&!rows.length)p(el('history'),'Nenhuma transferência neste filtro.');
  offset+=rows.length;el('more').hidden=rows.length<25;
}
async function loadAudit(){const rows=await checked(db.from('credit_audit_events').select('action,outcome,reason,created_at').eq('actor_id',user.id).order('created_at',{ascending:false}).limit(20));el('audit').replaceChildren();const labels={beneficiary_save:'Beneficiário salvo',beneficiary_remove:'Beneficiário removido',client_transfer:'Transferência simulada'};for(const r of rows)p(el('audit'),`${date(r.created_at)} · ${labels[r.action]||r.action} · ${r.outcome==='success'?'Concluído':'Recusado'}${r.reason?' · '+r.reason:''}`);if(!rows.length)p(el('audit'),'Sem eventos registrados.');}
async function refresh(){await loadAccounts();await loadBeneficiaries();await history();await loadAudit();}
async function receipt(id) {
  const t=await checked(db.from('credit_client_transfers').select('id,source_account_id,destination_account_id,source_name,destination_name,amount,description,created_at,environment').eq('id',id).single());
  const lines=['COMPROVANTE DE SIMULAÇÃO — SEM VALOR BANCÁRIO',`Identificador: ${t.id}`,`Ambiente: ${t.environment}`,`Data de registro: ${date(t.created_at)}`,`Origem: ${t.source_name}`,`Conta de origem: ${t.source_account_id}`,`Destino: ${t.destination_name}`,`Conta de destino: ${t.destination_account_id}`,`Valor fictício: ${money(t.amount)}`,`Descrição: ${t.description}`,'Status: simulação concluída. Nenhum dinheiro real foi movimentado.'];
  receiptText=lines.join('\n');receiptId=t.id;el('receipt-content').replaceChildren();const title=document.createElement('h2');title.textContent=lines.shift();el('receipt-content').append(title);lines.forEach(line=>p(el('receipt-content'),line));if(!el('receipt').open)el('receipt').showModal();
}
el('auth').onsubmit=e=>{e.preventDefault();run(async()=>{const b=e.target.querySelector('button');b.disabled=true;try{const f=new FormData(e.target);await checked(db.auth.signInWithPassword({email:f.get('email'),password:f.get('password')}));e.target.reset();message('');await init();}finally{b.disabled=false;}});};
el('beneficiary-form').onsubmit=e=>{e.preventDefault();run(async()=>{const b=e.target.querySelector('button');b.disabled=true;try{const f=new FormData(e.target);await checked(db.rpc('credit_beneficiary_save',{p_account:f.get('account').trim(),p_nickname:f.get('nickname').trim()}));e.target.reset();await loadBeneficiaries();message('Beneficiário salvo. Confira o titular antes de transferir.');}finally{b.disabled=false;await loadAudit();}});};
let pending;
el('transfer-form').onsubmit=e=>{e.preventDefault();run(async()=>{
  if(busy)return; const f=new FormData(e.target),a=accounts.find(x=>x.id===f.get('source')),b=beneficiaries.find(x=>x.id===f.get('beneficiary'));
  if(!a||!b)throw new Error('Selecione a origem e o beneficiário.');
  const fields={p_source:a.id,p_beneficiary:b.id,p_amount:Number(f.get('amount')),p_description:f.get('description').trim()};
  const key='cdb-transfer-pending:'+user.id, signature=JSON.stringify(fields);
  const cached=JSON.parse(sessionStorage.getItem(key)||'null');
  // Keep the same request ID on uncertain network results and page reloads.
  pending={...fields,p_request:cached?.signature===signature?cached.id:crypto.randomUUID()};
  sessionStorage.setItem(key,JSON.stringify({signature,id:pending.p_request}));
  el('review-details').replaceChildren();[`${a.display_name} → ${b.recipient_name}`,`Conta de destino: ${b.account_id}`,`Valor fictício: ${money(fields.p_amount)}`,`Descrição: ${fields.p_description}`].forEach(x=>p(el('review-details'),x));el('review').showModal();
});};
el('confirm').onclick=()=>run(async()=>{
  if(busy||!pending)return;busy=true;el('confirm').disabled=true;el('cancel').disabled=true;el('send').disabled=true;
  try{const result=await checked(db.rpc('credit_client_transfer',pending));sessionStorage.removeItem('cdb-transfer-pending:'+user.id);el('review').close();el('transfer-form').reset();pending=null;message('Transferência simulada concluída.');await receipt(result.id);await refresh();}
  catch(e){el('review').close();message('Transferência não confirmada: '+e.message+'. Em falha de conexão, consulte o histórico ou repita os mesmos dados; a repetição não duplica o débito.');await loadAudit();}
  finally{busy=false;el('confirm').disabled=false;el('cancel').disabled=false;el('send').disabled=false;}
});
el('cancel').onclick=()=>el('review').close();el('review').addEventListener('cancel',e=>{if(busy)e.preventDefault();});
el('close-receipt').onclick=()=>el('receipt').close();el('print').onclick=()=>window.print();
el('download').onclick=()=>{const url=URL.createObjectURL(new Blob([receiptText],{type:'text/plain;charset=utf-8'}));const a=document.createElement('a');a.href=url;a.download=`simulacao-${receiptId}.txt`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
el('refresh').onclick=()=>run(refresh);el('direction').onchange=()=>run(()=>history());el('more').onclick=()=>run(async()=>{el('more').disabled=true;try{await history(false);}finally{el('more').disabled=false;}});
el('logout').onclick=()=>run(async()=>{await checked(db.auth.signOut());location.reload();});
db.auth.onAuthStateChange(event=>{if(event==='SIGNED_OUT'){el('work').hidden=true;el('login').hidden=false;el('logout').hidden=true;el('receipt').close();el('review').close();}});
run(init);
