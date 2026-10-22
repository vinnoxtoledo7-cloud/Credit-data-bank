const fs=require('node:fs');const assert=require('node:assert/strict');const {randomUUID}=require('node:crypto');
const root='https://jruspbiljejmknjvnesd.supabase.co',key='sb_publishable_02sp2eGomD108oDM1Be8yg_-z7URJmT';
const users=JSON.parse(fs.readFileSync(process.env.QA_USERS_FILE,'utf8'));
async function request(path,token,body){const r=await fetch(root+path,{method:body?'POST':'GET',headers:{apikey:key,...(token?{Authorization:'Bearer '+token}:{}),'Content-Type':'application/json'},...(body?{body:JSON.stringify(body)}:{})});const data=await r.json();if(!r.ok)throw new Error('HTTP '+r.status+' '+JSON.stringify(data));return data;}
(async()=>{const sessions=[];try{
 for(const u of users){const s=await request('/auth/v1/token?grant_type=password',null,{email:u.email,password:u.password});assert(s.access_token);sessions.push(s.access_token);}
 const [sender,recipient]=sessions;
 const b=await request('/rest/v1/rpc/credit_beneficiary_save',sender,{p_account:users[1].account,p_nickname:'QA API beneficiary'});assert(b.id);
 const params={p_source:users[0].account,p_beneficiary:b.id,p_amount:12.34,p_description:'QA API integration',p_request:randomUUID()};
 const results=await Promise.all(Array.from({length:3},()=>request('/rest/v1/rpc/credit_client_transfer',sender,params)));
 assert(results.every(r=>r.id===results[0].id));assert.equal(results.filter(r=>!r.replayed).length,1);
 const receipt=await request('/rest/v1/credit_client_transfers?id=eq.'+results[0].id,recipient);assert.equal(receipt.length,1);assert.equal(receipt[0].amount,12.34);assert.equal(receipt[0].environment,'homologacao');
 const balance=await request('/rest/v1/rpc/credit_account_balances',recipient,{});assert.equal(Number(balance[0].balance),12.34);
 const hidden=await request('/rest/v1/credit_beneficiaries',recipient);assert.equal(hidden.length,0);
 const attempts=await Promise.all([1,2].map(()=>request('/rest/v1/rpc/credit_client_transfer',sender,{...params,p_amount:60,p_request:randomUUID()})));
 assert.equal(attempts.filter(x=>x.id).length,1);assert.equal(attempts.filter(x=>x.error==='Saldo fictício insuficiente').length,1);
 const remaining=await request('/rest/v1/rpc/credit_account_balances',sender,{});assert.equal(Number(remaining[0].balance),27.66);
 console.log('PASS: real HTTP login for 2 customers, beneficiary RPC, 3 simultaneous retries create 1 transfer, recipient receipt and balance, RLS isolation, competing debits prevent overdraft');
 }finally{for(const token of sessions)await fetch(root+'/auth/v1/logout',{method:'POST',headers:{apikey:key,Authorization:'Bearer '+token}});}})().catch(e=>{console.error(e.message);process.exit(1)});
