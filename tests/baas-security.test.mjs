// Node.js built-in tests. Run: node --test tests/baas-security.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const base=new URL('../',import.meta.url);
async function source(path){return readFile(new URL(path,base),'utf8');}
async function handler(path){
 const src=await source(path);
 // Source is an ESM default export; import via data URL without dependencies.
 return (await import('data:text/javascript;charset=utf-8,'+encodeURIComponent(src))).default;
}
function response(){
 return {headers:{},statusCode:200,body:null,setHeader(k,v){this.headers[k]=v;return this;},status(v){this.statusCode=v;return this;},json(v){this.body=v;return this;}};
}
test('no anonymous profile access',async()=>{
 const h=await handler('api/baas/my-profiles.js');
 const res=response();await h({method:'GET',headers:{}},res);
 assert.equal(res.statusCode,401);
 assert.equal(res.body.error,'authentication_required');
});
test('invalid HTTP method is rejected',async()=>{
 const h=await handler('api/baas/my-profiles.js');
 const res=response();await h({method:'POST',headers:{}},res);
 assert.equal(res.statusCode,405);
});
test('real transfer requests remain blocked',async()=>{
 const h=await handler('api/baas/transfers.js');
 const res=response();await h({method:'POST'},res);
 assert.equal(res.statusCode,503);
 assert.equal(res.body.error,'baas_unavailable');
});
test('unverified webhooks remain blocked',async()=>{
 const h=await handler('api/baas/webhooks.js');
 const res=response();await h({method:'POST'},res);
 assert.equal(res.statusCode,503);
});
test('profile lookup uses the authenticated caller identity and scoped bearer token',async()=>{
 const s=await source('api/baas/my-profiles.js');
 assert.match(s,/\/auth\/v1\/user/);
 assert.match(s,/owner_id/);
 assert.match(s,/user\.id/);
 assert.doesNotMatch(s,/SERVICE_ROLE|service_role/);
});

test('profile lookup scopes requests independently for two authenticated users',async()=>{
 const h=await handler('api/baas/my-profiles.js');
 const oldFetch=globalThis.fetch;
 const oldUrl=process.env.SUPABASE_URL;
 const oldKey=process.env.SUPABASE_PUBLISHABLE_KEY;
 process.env.SUPABASE_URL='https://sandbox.example.invalid';
 process.env.SUPABASE_PUBLISHABLE_KEY='public-test-key';
 const calls=[];
 globalThis.fetch=async (url,opts)=>{
  const path=new URL(url).pathname;
  if(path==='/auth/v1/user'){
   return {ok:true,json:async()=>({id:opts.headers.Authorization==='Bearer token-one'?'11111111-1111-4111-8111-111111111111':'22222222-2222-4222-8222-222222222222'})};
  }
  calls.push({url:String(url),headers:opts.headers});
  return {ok:true,json:async()=>([])};
 };
 try{
  for(const token of ['token-one','token-two']){
   const res=response();
   await h({method:'GET',headers:{authorization:'Bearer '+token}},res);
   assert.equal(res.statusCode,200);
  }
  assert.equal(calls.length,2);
  assert.match(calls[0].url,/owner_id=eq\.11111111-1111-4111-8111-111111111111/);
  assert.match(calls[1].url,/owner_id=eq\.22222222-2222-4222-8222-222222222222/);
  assert.notEqual(calls[0].headers.Authorization,calls[1].headers.Authorization);
 }finally{
  globalThis.fetch=oldFetch;
  if(oldUrl===undefined)delete process.env.SUPABASE_URL;else process.env.SUPABASE_URL=oldUrl;
  if(oldKey===undefined)delete process.env.SUPABASE_PUBLISHABLE_KEY;else process.env.SUPABASE_PUBLISHABLE_KEY=oldKey;
 }
});
