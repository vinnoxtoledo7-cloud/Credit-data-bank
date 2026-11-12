// Live homologation only; disposable identities supplied outside git. Independent HTTP requests/sessions.
const fs=require('node:fs'),assert=require('node:assert/strict'),{randomUUID}=require('node:crypto');
const users=JSON.parse(fs.readFileSync(process.env.QA_USERS_FILE,'utf8'));
const base='https://jruspbiljejmknjvnesd.supabase.co',key='sb_publishable_02sp2eGomD108oDM1Be8yg_-z7URJmT';
const sessions=[];const passed=[];
async function req(path,token,body){const r=await fetch(base+path,{method:body?'POST':'GET',headers:{apikey:key,...(token?{Authorization:'Bearer '+token}:{}),'Content-Type':'application/json',Prefer:'return=representation'},...(body?{body:JSON.stringify(body)}:{})});const d=await r.json();return{ok:r.ok,data:d};}
async function call(name,token,body){const r=await req('/rest/v1/rpc/'+name,token,body);if(!r.ok||r.data?.error)throw Error(r.data?.error||r.data?.message||String(r.data));return r.data;}
async function login(u){const r=await req('/auth/v1/token?grant_type=password',null,{email:u.email,password:u.password});assert(r.ok,'Fixture login failed');sessions.push(r.data.access_token);return r.data.access_token;}
(async()=>{try{
 const [sender,recipient,outsider,parallel]=await Promise.all([login(users[0]),login(users[1]),login(users[2]),login(users[0])]);
 passed.push('4 independent authenticated sessions');
 const source=users[0].account;
 const seed={p_account:source,p_kind:'demo_credit',p_amount:100,p_description:'QA isolated seed',p_request:randomUUID()};
 const seedIds=await Promise.all([sender,parallel].map(t=>call('credit_demo_entry_idempotent',t,seed)));assert.equal(seedIds[0],seedIds[1]);passed.push('entry concurrent idempotency');
 const b=await call('credit_beneficiary_save',sender,{p_account:users[1].account,p_nickname:'QA recipient'});
 const p={p_source:source,p_beneficiary:b.id,p_amount:60,p_description:'QA competing debit',p_request:randomUUID()};
 const races=await Promise.allSettled([call('credit_client_transfer',sender,p),call('credit_client_transfer',parallel,{...p,p_request:randomUUID()})]);
 assert.equal(races.filter(r=>r.status==='fulfilled').length,1);assert.match(races.find(r=>r.status==='rejected').reason.message,/insuficiente/);passed.push('competing debits: one success, one insufficient funds');
 const won=races.find(r=>r.status==='fulfilled').value;const transfer=(await req('/rest/v1/credit_client_transfers?id=eq.'+won.id,sender)).data[0];
 const retry={...p,p_request:transfer.request_id};const replays=await Promise.all([sender,parallel].map(t=>call('credit_client_transfer',t,retry)));assert(replays.every(x=>x.id===won.id&&x.replayed));passed.push('simultaneous identical transfer retries');
 await assert.rejects(call('credit_client_transfer',sender,{...retry,p_amount:59}),/outros dados/);passed.push('same key different payload rejected');
 await assert.rejects(call('credit_client_transfer',sender,{...p,p_amount:41,p_request:randomUUID()}),/insuficiente/);passed.push('insufficient funds rejected');
 await assert.rejects(call('credit_beneficiary_save',sender,{p_account:randomUUID(),p_nickname:'QA missing'}));passed.push('nonexistent account rejected');
 await assert.rejects(call('credit_client_transfer',outsider,{...p,p_request:randomUUID()}));passed.push('unauthorized transfer rejected');
 for(const amount of [0,-1,0.001,1000001])await assert.rejects(call('credit_client_transfer',sender,{...p,p_amount:amount,p_request:randomUUID()}));passed.push('zero, negative, fractional cent and over-limit rejected');
 const hidden=await req('/rest/v1/credit_account_ledger?account_id=eq.'+source,outsider);assert.deepEqual(hidden.data,[]);await assert.rejects(call('credit_transfer_receipt',outsider,{p_id:won.id}));passed.push('foreign ledger and receipt denied');
 for(const token of [sender,recipient]){const receipt=await call('credit_transfer_receipt',token,{p_id:won.id});assert.equal(receipt.reconciled,true);assert.equal(receipt.ledger.length,2);}passed.push('both participants receive reconciled receipt');
 const balance=await call('credit_account_balances',sender,{});assert.equal(Number(balance.find(a=>a.account_id===source).balance),40);passed.push('ledger balance exactly 40');
 const own=await req('/rest/v1/credit_accounts',sender,{owner_id:users[0].id,account_type:'PJ',display_name:'QA own destination'});assert(own.ok);users[0].extraAccount=own.data[0].id;fs.writeFileSync(process.env.QA_USERS_FILE,JSON.stringify(users),{mode:0o600});
 const self={p_source:source,p_destination:own.data[0].id,p_amount:10,p_description:'QA own transfer',p_request:randomUUID()};const ids=await Promise.all([sender,parallel].map(t=>call('credit_demo_transfer_idempotent',t,self)));assert.equal(ids[0],ids[1]);await assert.rejects(call('credit_demo_transfer_idempotent',sender,{...self,p_amount:11}),/outros dados/);passed.push('own transfer concurrent replay and payload mismatch');
 const ownReceipt=await call('credit_transfer_receipt',sender,{p_id:ids[0]});assert.equal(ownReceipt.reconciled,true);passed.push('own transfer two ledger entries reconciled');
 console.log(JSON.stringify({passed,failed:0},null,2));
 }finally{for(const token of sessions)await fetch(base+'/auth/v1/logout',{method:'POST',headers:{apikey:key,Authorization:'Bearer '+token}});}})().catch(e=>{console.error(JSON.stringify({passed,error:e.message},null,2));process.exitCode=1;});
