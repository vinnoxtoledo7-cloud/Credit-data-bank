import{test}from'node:test';import assert from'node:assert/strict';import{selectProvider,operations}from'../integrations/providers/index.js';
for(const provider of ['celcoin','asaas']){
 test(provider+' mock contract and explicit unsupported operations',async()=>{const a=selectProvider({provider});for(const op of operations)assert.equal(typeof a[op],'function');const t=await a.createTransfer({sourceAccountId:'a',destinationAccountId:'b',amountCents:100,method:'internal',idempotencyKey:'test_123456789012345'});assert.equal(t.provider,'mock');assert.equal(t.selectedProvider,provider);await assert.rejects(a.createAccount({}),/not_implemented/);assert.equal((await a.getServiceStatus()).productionEnabled,false);});
 test(provider+' sandbox fails closed without implementation',async()=>{await assert.rejects(selectProvider({provider,mode:'SANDBOX'}).getBalance(),/credentials_and_contract/);});
}
test('no configuration enables production',()=>{for(const mode of ['PRODUCTION','live','production',''])assert.throws(()=>selectProvider({provider:'asaas',mode}),/production_disabled/);});
test('none disables all operations',async()=>{await assert.rejects(selectProvider().createTransfer({}),/provider_disabled/);});
