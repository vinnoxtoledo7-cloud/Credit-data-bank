/**
 * Credit Data Bank — BaaS integration contract (sandbox only).
 * No credentials, financial balances or live payment instructions belong in this file.
 * Server-side adapters must implement this contract after provider onboarding.
 */
export const BaaSMode=Object.freeze({SANDBOX:'sandbox',LIVE:'live'});
export const BaaSStatus=Object.freeze({PENDING:'pending',PROCESSING:'processing',COMPLETED:'completed',FAILED:'failed',REVERSED:'reversed'});
export class BaaSUnavailableError extends Error{
  constructor(){super('Integração BaaS indisponível: aguardando contratação e homologação.');this.name='BaaSUnavailableError'}
}
export function validateTransferIntent(intent){
  if(!intent||typeof intent!=='object')throw new TypeError('Transferência inválida');
  if(!Number.isSafeInteger(intent.amountCents)||intent.amountCents<=0)throw new TypeError('Valor inválido em centavos');
  if(typeof intent.idempotencyKey!=='string'||!/^[a-zA-Z0-9_-]{16,128}$/.test(intent.idempotencyKey))throw new TypeError('Chave de idempotência inválida');
  if(!['pix','internal','ted'].includes(intent.method))throw new TypeError('Método inválido');
  return Object.freeze({amountCents:intent.amountCents,idempotencyKey:intent.idempotencyKey,method:intent.method});
}
/** Disabled by default. Never send funds from the browser or mock adapter. */
export function createBaaSAdapter({mode=BaaSMode.SANDBOX}={}){
  if(mode!==BaaSMode.SANDBOX)throw new BaaSUnavailableError();
  const unavailable=async()=>{throw new BaaSUnavailableError()};
  return Object.freeze({
    mode,provider:'unconfigured',ready:false,
    createAccount:unavailable,getAccount:unavailable,
    registerPixKey:unavailable,createPixCharge:unavailable,
    createTransfer:unavailable,getTransfer:unavailable,
    getBalance:unavailable,getStatement:unavailable
  });
}
