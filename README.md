# Credit Data Bank v1.0 | Homologação

Portal responsivo demonstrativo, sem produtos financeiros operacionais.

## Implantação
1. Envie `index.html`, `app.js`, `styles.css`, `vercel.json` e este README para a raiz do repositório GitHub conectado à Vercel.
2. Na Vercel, use framework **Other** e diretório raiz `/`. Para projeto estático, não defina comando de build nem output directory.
3. Publique a branch `main` e valide o deployment. O projeto Supabase já está referenciado em `app.js` com chave pública publishable.
4. No Supabase Authentication, configure `Site URL` e URLs de redirecionamento com os endereços efetivamente publicados. Habilite confirmação de e-mail conforme política do projeto.
5. Crie usuários de teste e valide os fluxos descritos abaixo antes de divulgar o link.

## Recursos
- Login, registro por e-mail e solicitação de redefinição de senha via Supabase Auth.
- Formulários PF/PJ: grava rascunho, envio para análise, listagem do proprietário.
- Administração: leitura de até 100 cadastros, aprovação e rejeição dos enviados, conforme RLS existente.
- Dashboard, Pix, contas, extrato e cartões exclusivamente ilustrativos.

## Modelo de dados esperado
`public.customer_profiles` com `id`, `owner_id`, `account_type` (`PF`/`PJ`), `full_name`, `legal_name`, `email`, `phone`, `status` (`draft`, `submitted`, `under_review`, `approved`, `rejected`), `created_at`.
`public.admin_members` com `user_id` de administradores. RLS e triggers existentes devem permanecer ativos.

## Roteiro de testes manuais obrigatório
- [ ] Usuário existente faz login, logout e solicita redefinição de senha.
- [ ] Novo usuário cria acesso, confirma e-mail e entra (depende de configurações de Auth).
- [ ] Usuário cria rascunho PF e PJ, visualiza apenas seus próprios cadastros e os envia para análise.
- [ ] Usuário comum não acessa área administrativa nem perfis de terceiros.
- [ ] Administrador consulta solicitações e aprova/rejeita somente as enviadas.
- [ ] Tentativas de alterar cadastros de terceiros e estados não autorizados são negadas por RLS/triggers.
- [ ] Layout mobile, mensagens de erro e acessibilidade básica.
- [ ] Confirmar que não existem pagamentos, contas bancárias ou cartões reais.

## Limites conhecidos
- Aprovação administrativa significa apenas revisão de cadastro, não KYC regulatório ou abertura de conta.
- Sem CPF/CNPJ obrigatório, upload documental, análise antifraude, trilha de auditoria dedicada ou integração Celcoin.
- Recuperação de senha usa link por e-mail e tela de definição de senha; validar redirecionamento real em homologação.
- Listagem administrativa limitada a 100 registros; implementar paginação em fase posterior.
- Dependência CDN de supabase-js exige conexão à internet; antes de produção, migrar para build com dependências travadas.
- Não usar para captar documentos sensíveis ou disponibilizar serviços financeiros reais.
