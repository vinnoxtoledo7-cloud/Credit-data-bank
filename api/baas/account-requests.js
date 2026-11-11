// Sandbox account applications only. No real bank account is opened.
export default async function handler(req,res){
 res.setHeader('Cache-Control','no-store');
 res.setHeader('X-Content-Type-Options','nosniff');
 if(req.method!=='POST'){res.setHeader('Allow','POST');return res.status(405).json({error:'method_not_allowed'});}
 const token=(req.headers.authorization||'').match(/^Bearer ([A-Za-z0-9._~-]+)$/)?.[1];
 if(!token)return res.status(401).json({error:'authentication_required'});
 const {customer_profile_id,idempotency_key}=req.body||{};
 if(typeof customer_profile_id!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(customer_profile_id)
 ||typeof idempotency_key!=='string'||!/^[a-zA-Z0-9_-]{8,128}$/.test(idempotency_key))
 return res.status(400).json({error:'invalid_request'});
 const url=process.env.SUPABASE_URL;
 const key=process.env.SUPABASE_PUBLISHABLE_KEY||process.env.SUPABASE_ANON_KEY;
 if(!url||!key)return res.status(503).json({error:'sandbox_not_configured'});
 try{
  const base=new URL(url);
  if(base.protocol!=='https:')throw Error('invalid_configuration');
  const headers={apikey:key,Authorization:'Bearer '+token};
  const identity=await fetch(new URL('/auth/v1/user',base),{headers,signal:AbortSignal.timeout(8000)});
  if(!identity.ok)return res.status(401).json({error:'invalid_session'});
  const user=await identity.json();
  if(!user.id)return res.status(401).json({error:'invalid_session'});
  const endpoint=new URL('/rest/v1/sandbox_account_requests',base);
  endpoint.searchParams.set('select','id,customer_profile_id,status,created_at');
  const result=await fetch(endpoint,{method:'POST',headers:{...headers,'Content-Type':'application/json',Prefer:'return=representation'},body:JSON.stringify({owner_id:user.id,customer_profile_id,idempotency_key}),signal:AbortSignal.timeout(8000)});
  if(result.status===409)return res.status(409).json({error:'duplicate_request'});
  if(result.status===401||result.status===403)return res.status(403).json({error:'not_authorized'});
  if(!result.ok)return res.status(502).json({error:'sandbox_request_failed'});
  const rows=await result.json();
  return res.status(201).json({mode:'sandbox',request:rows[0]});
 }catch(_){return res.status(503).json({error:'sandbox_unavailable'});}
}
