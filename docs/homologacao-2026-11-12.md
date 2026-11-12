# Credit Data Bank — auditoria e entrega de 12/11/2026

**Resultado: missão completa ainda PENDENTE. Este incremento não habilita dinheiro real.**

Infraestrutura preservada: `vinnoxtoledo7-cloud/Credit-data-bank`, `main`, Supabase `jruspbiljejmknjvnesd` (sa-east-1), domínio `https://credit-data-bank-homologacao.vercel.app`. Base auditada: `fd54a7f`. Nenhum projeto novo, contratação ou integração produtiva.

## Evidências executadas

| Verificação | Resultado | Evidência |
|---|---|---|
| APIs BaaS, mocks, PDF e CSV | TESTADO | `node --test tests/*.test.mjs`: 18 passaram, 0 falharam |
| Concorrência HTTP autenticada | TESTADO | `tests/financial-concurrency.cjs`: 14 verificações, quatro sessões, três usuários descartáveis |
| Transferências entre clientes e RLS | TESTADO | `tests/client-transfers.sql`: PASS com rollback |
| RPCs legadas e dupla aprovação | TESTADO | `tests/legacy-security.sql`: PASS com rollback |
| Falha após débito e antes do crédito | TESTADO | `tests/atomic-failure.sql`: trigger restrito ao fixture, débito e transferência revertidos, rollback final |
| Conciliação administrativa | TESTADO | Teste acima nega usuário comum, permite admin de fixture em transação revertida |
| Conciliação dos registros existentes + QA | TESTADO | 3 transferências, 0 divergências na consulta executada antes da limpeza |
| PDF com português | TESTADO | `pdftotext` extraiu aviso, acentos e valor corretamente; teste verifica offsets e paginação |
| Login via Supabase HTTP | TESTADO | Quatro sessões reais de Auth com identidades descartáveis; logout executado no finally |
| Login e recuperação visual | TESTADO | Navegador abriu a aplicação publicada e alternou para formulário de recuperação |
| Recebimento do e-mail de recuperação | PENDENTE | Nenhuma caixa de e-mail de QA validada |
| Fluxo visual autenticado/mobile | BLOQUEADO | Navegador exige entrada segura de credenciais pelo usuário; não substituído por login HTTP |
| Conta bloqueada | PENDENTE | Modelo atual só admite status sandbox; suspensão/encerramento ainda não implementados |

O primeiro teste legado falhou porque esperava “Sem autorização financeira”; a proteção nova recusou antes com “Criador não pode aprovar a própria folha”. A expectativa foi atualizada e a execução passou. Isso não era falha de saldo. Os testes da futura folha financiada **não** foram executados, porque sua migração não foi aplicada.

## Alterações efetivamente aplicadas ao Supabase

Migração `readiness_integrity` (arquivo versionado `20261112161754_readiness_integrity.sql`):

- Revogação de privilégios de anon nas tabelas de folha; retirada de TRUNCATE, REFERENCES e TRIGGER desnecessários dos clientes; eventos de aprovação e atribuição de aprovadores sem escrita direta.
- RLS em `credit_private.demo_entry_requests`; implementação privilegiada de `credit_demo_entry_idempotent` movida para schema privado, mantendo assinatura pública invoker.
- `credit_demo_transfer_idempotent`: trava por usuário/chave, verificação de payload e índice único de solicitação. A função legada sem chave permanece para compatibilidade; a interface nova usa a função idempotente.
- Itens da folha travam a linha do lote, como submit/approve; não podem mudar de lote/funcionário. Criador não pode aprovar a própria folha.
- `credit_transfer_receipt`: autoriza apenas participantes, verifica exatamente um débito e um crédito e devolve IDs vinculados. Histórico alheio continua inacessível.
- `credit_reconciliation_report`: leitura administrativa auditada, sem ajustes históricos automáticos. Detecta pares ausentes/duplicados/divergentes, referências duplas e saldos negativos. Não é conciliação com provedor externo.

A migração adicional `payroll_item_lock_privileges` moveu o trigger de bloqueio para implementação privada definer, sem EXECUTE de cliente. Um teste de inserção autenticada detectou falta de privilégio de UPDATE necessário ao lock na implementação invoker inicial. Corrigido sem conceder UPDATE ao cliente; `tests/payroll-item-lock.sql` passou após a correção.

## Código preparado

Comprovantes consultados no servidor antes da apresentação, exportação PDF, transferências próprias com reenvio idempotente, paginação/filtros de data/tipo e CSV/PDF **da página atual** do extrato, painel administrativo de conciliação, estilo compartilhado azul-marinho/laranja e estados desabilitados. Nenhum desses ajustes de tela substitui teste visual autenticado completo.

APIs de perfis e solicitações agora aceitam os nomes `VITE_SUPABASE_URL` e `VITE_SUPABASE_PUBLISHABLE_KEY` já presentes na Vercel. Antes esperavam apenas nomes diferentes e podiam retornar indisponibilidade. Continuam consultando Auth e REST com o token do próprio usuário e RLS, sem chave administrativa.

CSP em **Report-Only**, gerada com hashes dos scripts inline. Ainda não bloqueia XSS: ativar enforcement somente após validar fluxos autenticados e dependências. Permissions-Policy bloqueia câmera/microfone/geolocalização não usados. O cliente Supabase ainda usa armazenamento padrão de sessão do SDK; migração para sessão via backend/cookies HttpOnly permanece pendente.

## Bloqueios observados

1. `docs/pending/payroll_funding.sql`: aplicação solicitada duas vezes; a confirmação da integração expirou em ambas. Consulta ao catálogo confirmou ausência de `payroll_simulate_funded`. Arquivo retirado da pasta de migrações ativas para evitar aplicação inadvertida. **Não aplicado e não validado.** Propõe snapshot no envio, débito atômico, vínculo do lançamento e replay; exige teste completo, interface de origem e procedimento para lotes históricos.
2. `docs/pending/cleanup-disposable-qa.sql`: confirmação de exclusão expirou. Os três usuários e quatro contas são fictícios, marcados `qa=readiness-20261112`; permanecem segregados. Logout foi feito e arquivo local de senhas aleatórias removido. Limpeza não foi declarada concluída. Script filtra IDs exatos e marcador antes de excluir. Nenhum saldo de cliente existente foi usado.
3. Proteção contra senhas vazadas está desabilitada; histórico da auditoria identificou dependência de plano pago. Não houve upgrade.
4. Logs Vercel em 1h foram recusados pela retenção; consulta corrigida para 15min retornou zero grupos de erro. Não comprova ausência de erros fora da janela.

## Pendências por módulo

| Módulo | Estado real |
|---|---|
| Cadastro PF/PJ | PENDENTE: validação CPF/CNPJ no servidor, representantes, edição, under_review, relação perfil-conta |
| Contas | PENDENTE: suspensão/encerramento e teste de conta bloqueada |
| Saldos e transferências | TESTADO para cenários descritos; PENDENTE ampliar limites/rate limiting de todas as RPCs legadas e auditoria de recusas próprias |
| Extratos e comprovantes | PENDENTE validação visual autenticada do código preparado, filtros de valor e exportação integral |
| Payroll | TESTADO fluxo legado/segregação; BLOQUEADO controle de saldo proposto; PENDENTE Excel, cancelamento, relatórios e comprovantes individuais financiados |
| Conciliação | TESTADO mecanismo interno; PENDENTE folha financiada, órfãos sem referência obrigatória e parceiro externo |
| Segurança | PENDENTE MFA administrativo, sessão HttpOnly, gestão de operador/representantes, política completa de retenção e incidentes |
| BaaS | TESTADO contrato mock e assinatura própria de teste; PENDENTE adaptador Celcoin contratado, inbox durável e worker operacional |
| Layout | PENDENTE validação do CSS compartilhado em Android/iPhone/tablet e integração completa do dashboard aos saldos |
| CI | TESTADO localmente nos testes Node; PENDENTE execução remota do novo commit e CI autenticada isolada |
| Backup/restauração | PENDENTE ensaio de restauração e confirmação de cobertura do plano |
| Compliance | PENDENTE avaliação jurídica, bases legais/termos/consentimentos, KYC/KYB/PLD operacional |

A aplicação não está certificada, autorizada como instituição financeira nem pronta para dinheiro real. Não encerrar a missão enquanto os critérios pendentes não forem efetivamente validados.
