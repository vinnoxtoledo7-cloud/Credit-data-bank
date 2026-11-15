// Pure reconciliation: never writes either financial ledger.
export function reconcileConfirmed({internal,external}){
 if(!internal||!external)throw Error('records_required');
 const issues=[];
 for(const row of [internal,external])if(!Number.isSafeInteger(row.amountCents)||row.amountCents<=0)throw Error('invalid_amount');
 if(internal.provider!==external.provider)issues.push('provider_mismatch');
 if(internal.environment!==external.environment)issues.push('environment_mismatch');
 if(internal.externalId!==external.id)issues.push('reference_mismatch');
 if(internal.amountCents!==external.amountCents)issues.push('amount_mismatch');
 if(!['pending','processing','completed','failed','reversed'].includes(external.status))issues.push('unknown_external_status');
 if(internal.status!==external.status)issues.push('status_mismatch');
 if(external.confirmedByQuery!==true)issues.push('provider_query_required');
 return Object.freeze({consistent:issues.length===0,issues:Object.freeze(issues),automaticAdjustment:false});
}
export function nextVerifiedState(current,event,confirmed){
 if(!confirmed||confirmed.confirmedByQuery!==true)throw Error('provider_query_required');
 // Ignore webhook order: authoritative query drives the result, including reversal.
 if(event.externalId!==confirmed.id)throw Error('reference_mismatch');
 if(!['pending','processing','completed','failed','reversed'].includes(confirmed.status))throw Error('unknown_external_status');
 if(['completed','reversed'].includes(current)&&['pending','processing'].includes(confirmed.status))throw Error('state_regression_requires_review');
 return confirmed.status;
}
