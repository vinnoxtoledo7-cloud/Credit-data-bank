// Read-only sandbox status. Supabase RLS restricts results to the signed-in owner.
export default async function handler(req,res){
 res.setHeader('Cache-Control','no-store');
 res.setHeader('X-Content-Type-Options','nosniff');
 if(req.method!=='GET'){res.setHeader('Allow','GET');return res.status(405).json({error:'method_not_allowed'});}
 const token=(req.headers.authorization||'').match(/^Bearer ([A-Za-z0-9._~-]+)$/)?.[1];
 if(!token)return res.status(401).json({error:'authentication_required'});
 const url=process.env.SUPABASE_URL;
 const key=process.env.SUPABASE_PUBLISHABLE_KEY||process.env.SUPABASE_ANON_KEY;
 if(!url||!key)return res.status(503).json({error:'sandbox_not_configured'});
 try{
  const base=new URL(url);
  if(base.protocol!=='https:')throw new Error('invalid_configuration');
  const headers={apikey:key,Authorization:'Bearer '+token};
  const identity=await fetch(new URL('/auth/v1/user',base),{headers,signal:AbortSignal.timeout(8000)});
  if(!identity.ok)return res.status(401).json({error:'invalid_session'});
  const user=await identity.json();
  if(!user.id)return res.status(401).json({error:'invalid_session'});
  const endpoint=new URL('/rest/v1/sandbox_account_requests',base);
  endpoint.searchParams.set('select','id,customer_profile_id,status,created_at');
  endpoint.searchParams.set('owner_id','eq.'+user.id);
  endpoint.searchParams.set('order','created_at.desc');
  endpoint.searchParams.set('limit','50');
  const result=await fetch(endpoint,{headers,signal:AbortSignal.timeout(8000)});
  if(!result.ok)return res.status(502).json({error:'sandbox_lookup_failed'});
  return res.status(200).json({mode:'sandbox',requests:await result.json()});
 }catch(_){return res.status(503).json({error:'sandbox_unavailable'});}
}
