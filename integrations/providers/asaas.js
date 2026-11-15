// Backend-only, read-only sandbox transport. No write/payment endpoint is exposed.
const BASE='https://api-sandbox.asaas.com/v3';
export function createAsaasSandbox({apiKey,fetchImpl=fetch,timeoutMs=8000}={}){
 if(typeof apiKey!=='string'||!apiKey.trim())throw Error('sandbox_credentials_required');
 if(!Number.isInteger(timeoutMs)||timeoutMs<1||timeoutMs>30000)throw Error('invalid_timeout');
 async function get(path){
  for(let attempt=0;attempt<2;attempt++){
   let r;try{r=await fetchImpl(BASE+path,{method:'GET',redirect:'error',headers:{access_token:apiKey,accept:'application/json','User-Agent':'CreditDataBank-Sandbox'},signal:AbortSignal.timeout(timeoutMs)});}catch{throw Error('provider_transport_error');}
   if(attempt===0&&[502,503,504].includes(r.status))continue;
   if(!r.ok)throw Error('provider_http_'+r.status);
   try{return await r.json();}catch{throw Error('provider_invalid_response');}
  }
 }
 const id=value=>{if(typeof value!=='string'||!/^[A-Za-z0-9_-]{1,100}$/.test(value))throw Error('invalid_resource_id');return value;};
 return Object.freeze({provider:'asaas',mode:'SANDBOX',getBalance:()=>get('/finance/balance'),getStatement:({offset=0,limit=50}={})=>{if(!Number.isSafeInteger(offset)||offset<0||!Number.isSafeInteger(limit)||limit<1||limit>100)throw Error('invalid_pagination');return get('/financialTransactions?offset='+offset+'&limit='+limit);},getCharge:paymentId=>get('/payments/'+id(paymentId)),getPixQrCode:paymentId=>get('/payments/'+id(paymentId)+'/pixQrCode')});
}
