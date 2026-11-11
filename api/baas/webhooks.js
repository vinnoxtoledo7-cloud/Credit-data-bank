// Inbound provider webhooks are intentionally disabled until the selected
// provider signature scheme and durable event storage have been implemented.
// Never accept, acknowledge, or apply an unverified financial event.
export default function handler(req,res){
  res.setHeader('Cache-Control','no-store');
  res.setHeader('X-Content-Type-Options','nosniff');
  if(req.method!=='POST'){res.setHeader('Allow','POST');return res.status(405).json({error:'method_not_allowed'});}
  return res.status(503).json({error:'webhook_not_configured',message:'Webhook financeiro indisponível até assinatura e validação do parceiro BaaS.'});
}
