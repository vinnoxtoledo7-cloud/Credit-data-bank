import{timingSafeEqual,createHash}from'node:crypto';
export function verifyAsaasToken(received,expected){
 if(typeof expected!=='string'||expected.length<32)throw Error('webhook_secret_not_configured');
 if(typeof received!=='string'||received.length>1024)throw Error('webhook_unauthorized');
 const hash=s=>createHash('sha256').update(s).digest();
 if(!timingSafeEqual(hash(received),hash(expected)))throw Error('webhook_unauthorized');return true;
}
// Verification alone MUST NOT acknowledge an event until durable storage commits.
