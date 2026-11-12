import fs from 'node:fs';import{createHash}from'node:crypto';
const hashes=new Set();for(const file of fs.readdirSync('.').filter(x=>x.endsWith('.html'))){for(const m of fs.readFileSync(file,'utf8').matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/g)){if(!/\bsrc=/.test(m[1])&&m[2].trim())hashes.add("'sha256-"+createHash('sha256').update(m[2]).digest('base64')+"'");}}
const csp=`default-src 'self'; script-src 'self' https://esm.sh ${[...hashes].join(' ')}; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' https://jruspbiljejmknjvnesd.supabase.co wss://jruspbiljejmknjvnesd.supabase.co; font-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'`;
const config=JSON.parse(fs.readFileSync('vercel.json'));const headers=config.headers[0].headers;const name='Content-Security-Policy-Report-Only';const item=headers.find(x=>x.key===name);if(item)item.value=csp;else headers.push({key:name,value:csp});
if(!headers.some(x=>x.key==='Permissions-Policy'))headers.push({key:'Permissions-Policy',value:'camera=(), microphone=(), geolocation=()'});
// Report-only until authenticated browser coverage confirms all CDN requests.
fs.writeFileSync('vercel.json',JSON.stringify(config,null,2)+'\n');
