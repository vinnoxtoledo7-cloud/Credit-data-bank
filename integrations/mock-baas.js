// Contract test adapter ONLY. No network calls or financial credentials.
// Runtime endpoints remain disabled. Replace in-memory stores with a durable inbox/outbox before deployment.
import {createHmac,timingSafeEqual,createHash} from 'node:crypto';
import {validateTransferIntent} from './baas-contract.js';
export function createMockAdapter(){
 const requests=new Map();
 return Object.freeze({provider:'mock',mode:'sandbox',async createTransfer(intent){
  validateTransferIntent(intent);
  if(!intent.sourceAccountId||!intent.destinationAccountId||intent.sourceAccountId===intent.destinationAccountId)throw Error('invalid_accounts');
  const signature=JSON.stringify([intent.sourceAccountId,intent.destinationAccountId,intent.amountCents,intent.method]);
  const existing=requests.get(intent.idempotencyKey);
  if(existing){if(existing.signature!==signature)throw Error('idempotency_conflict');return {...existing.result,replayed:true};}
  const result={id:'mock_'+createHash('sha256').update(intent.idempotencyKey).digest('hex').slice(0,24),status:'pending',environment:'sandbox',provider:'mock',replayed:false};
  requests.set(intent.idempotencyKey,{signature,result});return {...result};
 }});
}
export function signMockWebhook(body,timestamp,secret){return createHmac('sha256',secret).update(String(timestamp)+'.'+body).digest('hex');}
export function verifyMockWebhook({body,timestamp,signature,secret,now=Date.now()}){
 if(typeof secret!=='string'||secret.length<32)throw Error('mock_secret_required');
 if(typeof body!=='string'||Buffer.byteLength(body)>65536||!Number.isSafeInteger(timestamp)||Math.abs(now-timestamp)>300000||!(/^[a-f0-9]{64}$/).test(signature||''))throw Error('invalid_webhook');
 const expected=signMockWebhook(body,timestamp,secret);
 if(!timingSafeEqual(Buffer.from(signature,'hex'),Buffer.from(expected,'hex')))throw Error('invalid_signature');
 const event=JSON.parse(body);
 if(event.provider!=='mock'||typeof event.id!=='string'||!event.id||!['completed','failed'].includes(event.status))throw Error('invalid_event');
 return {event,sha256:createHash('sha256').update(body).digest('hex')};
}
export class MockInbox {
 #events=new Map();
 accept(verified){const previous=this.#events.get(verified.event.id);if(previous){if(previous.sha256!==verified.sha256)throw Error('event_conflict');return 'duplicate';}this.#events.set(verified.event.id,{...verified,attempts:0,status:'pending'});return 'accepted';}
 async process(handler){for(const record of this.#events.values()){if(record.status==='processed'||record.attempts>=3)continue;record.attempts++;try{await handler(record.event);record.status='processed';}catch{record.status=record.attempts>=3?'dead_letter':'retry';}}}
 status(id){const r=this.#events.get(id);return r?{status:r.status,attempts:r.attempts}:null;}
}
