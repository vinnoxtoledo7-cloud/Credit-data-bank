// Sandbox onboarding states are descriptive only, not bank-account creation.
export const OnboardingState=Object.freeze({
 DRAFT:'draft',SUBMITTED:'submitted',UNDER_REVIEW:'under_review',
 MORE_INFO_REQUIRED:'more_info_required',APPROVED:'approved',REJECTED:'rejected'
});
export const OnboardingType=Object.freeze({PERSON:'PF',BUSINESS:'PJ'});
export function validateOnboardingDraft(draft){
 if(!draft||typeof draft!=='object')throw new TypeError('Cadastro inválido');
 if(!Object.values(OnboardingType).includes(draft.type))throw new TypeError('Tipo PF/PJ inválido');
 const name=String(draft.name??'').trim();
 if(name.length<2||name.length>160)throw new TypeError('Nome ou razão social inválido');
 return Object.freeze({type:draft.type,name,status:OnboardingState.DRAFT});
}
