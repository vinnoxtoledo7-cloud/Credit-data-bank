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
