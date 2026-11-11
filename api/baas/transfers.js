// Intentionally fail closed: no provider has been onboarded.
export default function handler(req,res){
 res.setHeader('Cache-Control','no-store');
 res.setHeader('X-Content-Type-Options','nosniff');
 res.setHeader('Allow','POST');
 if(req.method!=='POST')return res.status(405).json({error:'method_not_allowed'});
 return res.status(503).json({
  error:'baas_unavailable',
  message:'Transferências reais desativadas até a integração segura e homologação do parceiro.'
 });
}
