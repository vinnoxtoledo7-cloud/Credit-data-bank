// Public, read-only readiness endpoint. Never include provider credentials here.
export default function handler(req,res){
 res.setHeader('Cache-Control','no-store');
 res.setHeader('X-Content-Type-Options','nosniff');
 if(req.method!=='GET'){res.setHeader('Allow','GET');return res.status(405).json({error:'method_not_allowed'})}
 return res.status(200).json({
  service:'credit-data-bank-baas',
  environment:'sandbox',
  provider:'unconfigured',
  enabled:false,
  capabilities:{accounts:false,pix:false,transfers:false,webhooks:false},
  message:'Aguardando credenciais de homologação e aprovação do parceiro BaaS.'
 });
}
