// Read-only authenticated profile lookup for future sandbox onboarding.
// Uses the caller's JWT and Supabase RLS. No service-role key is needed.
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
  const userResponse=await fetch(new URL('/auth/v1/user',base),{headers,signal:AbortSignal.timeout(8000)});
  if(!userResponse.ok)return res.status(401).json({error:'invalid_session'});
  const user=await userResponse.json();
  if(!user.id)return res.status(401).json({error:'invalid_session'});
  const query=new URL('/rest/v1/customer_profiles',base);
  query.searchParams.set('select','id,account_type,status,display_name');
  query.searchParams.set('owner_id','eq.'+user.id);
  query.searchParams.set('limit','50');
  const profilesResponse=await fetch(query,{headers,signal:AbortSignal.timeout(8000)});
  if(!profilesResponse.ok)return res.status(502).json({error:'profile_lookup_failed'});
  const profiles=await profilesResponse.json();
  return res.status(200).json({mode:'sandbox',userId:user.id,profiles});
 }catch(_error){return res.status(503).json({error:'identity_provider_unavailable'});}
}
