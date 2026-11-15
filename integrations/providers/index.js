import {createMockAdapter} from '../mock-baas.js';
export class IntegrationError extends Error{constructor(code){super(code);this.code=code;}}
export const operations=Object.freeze(['createAccount','getAccount','getBalance','getStatement','getBeneficiary','createCharge','getCharge','createTransfer','getTransfer','receiveEvent','reconcile']);
// Selection is server configuration only. Production cannot be enabled by config.
export function selectProvider({provider='none',mode='MOCK'}={}){
 if(!['none','celcoin','asaas'].includes(provider))throw new IntegrationError('unknown_provider');
 if(!['MOCK','SANDBOX'].includes(mode))throw new IntegrationError('production_disabled');
 const mock=createMockAdapter();
 const adapter={provider,mode,ready:mode==='MOCK',externalCalls:false};
 for(const operation of operations)adapter[operation]=async(...args)=>{
  if(provider==='none')throw new IntegrationError('provider_disabled');
  if(mode==='SANDBOX')throw new IntegrationError('sandbox_credentials_and_contract_required');
  if(operation==='createTransfer')return {...await mock.createTransfer(...args),selectedProvider:provider,provider:'mock'};
  throw new IntegrationError('operation_not_implemented');
 };
 adapter.getServiceStatus=async()=>({provider,mode,externalCalls:false,productionEnabled:false,supportedMockOperations:provider==='none'?[]:['createTransfer']});
 return Object.freeze(adapter);
}
