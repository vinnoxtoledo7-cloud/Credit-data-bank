# Preparação multiprovedor — estado verificável

## Entrega deste incremento

Contrato comum em `integrations/providers/index.js`, seleção server-side none/celcoin/asaas, modos MOCK/SANDBOX e bloqueio incondicional de produção. Transferências mock usam implementação idempotente existente e são identificadas como mock; nenhum resultado representa confirmação externa. Operações não implementadas retornam erro controlado. Nenhuma chamada externa é realizada.

24 testes Node executados e aprovados, incluindo seis novos testes de seleção, contratos, indisponibilidade sandbox e bloqueio produtivo. Não equivale a homologação oficial. Consulta ao catálogo confirmou RLS nas 22 tabelas existentes nos schemas public/credit_private/baas_private; presença de RLS não comprova adequação de cada política.

## Diferenças dos fornecedores

| Recurso | Celcoin | Asaas |
|---|---|---|
| Modelo | BaaS e onboarding conforme produtos contratados | Clientes/cobranças e serviços de conta/subconta conforme contrato; não equivalente automaticamente a banco completo |
| Auth | OAuth 2.0; requisitos mTLS e IP precisam ser confirmados por produto e versão | API key backend, confirmar versão e header na documentação antes de implementar |
| Sandbox | Dependente de credenciais e produto | Base documentada https://api-sandbox.asaas.com/v3 |
| Webhooks | Autenticação varia por produto; não presumir HMAC do mock | Token configurado conferido em asaas-access-token; entrega pode repetir |
| Implementação atual | MOCK de transferência; demais operações com erro explícito | MOCK de transferência; demais operações com erro explícito |

## Pendências técnicas (não confundir com ausência de credenciais)

- Implementar clientes HTTP separados, autenticação, endpoints verificados por recurso, timeouts e retry seguro apenas de leituras ou operações com idempotência oficialmente suportada. Não repetir POST financeiro após timeout sem consultar o estado externo.
- Implementar schemas normalizados de clientes, cobranças, QR code, transferências, saldo, extrato e reversões; mapear estados desconhecidos como pendentes de investigação.
- Implementar endpoints separados de webhook, validação efetiva, inbox/outbox duráveis, worker com lease e DLQ. Mock em memória não atende durabilidade.
- Não usar notificações como única fonte de conciliação; consultar recurso/extrato confirmado do parceiro. Eventos fora de ordem não podem regredir estado confirmado sem consulta.
- Completar mapeamento de contas externas, ledger de integração separado e reconciliação externa. Nunca copiar saldo fictício para ledger externo.
- Completar configuração administrativa auditada e protegida por MFA. Seleção por frontend não deve alterar ambiente financeiro.
- Validar políticas e grants, recuperação por e-mail, MFA, rate limiting, senhas comprometidas, backup/restauração e testes autenticados de UI.
- Executar CI remota e confirmar deployment associado ao commit final. Testes locais não substituem essa evidência.

## Dependências externas

Credenciais sandbox, contratação e escopo de produtos, aprovação do parceiro e jurídico/compliance. Não foram solicitadas ou configuradas credenciais produtivas. Homologação oficial de ambos está PENDENTE. Produção permanece bloqueada.

## Fontes oficiais consultadas

- https://docs.asaas.com/docs/sandbox
- https://docs.asaas.com/docs/receba-eventos-do-asaas-no-seu-endpoint-de-webhook
- https://docs.asaas.com/docs/faq-de-webhooks
- https://developers.celcoin.com.br/docs/obtendo-acesso-%C3%A0s-apis
- https://developers.celcoin.com.br/docs/mtls
- https://developers.celcoin.com.br/docs/gerenciamento-de-webhook

As páginas Celcoin apresentam orientações diferentes sobre liberação de IP/mTLS entre produtos/versões; confirmar a especificação contratada antes de configurar transporte.

## Rollback e monitoramento

Este incremento é aditivo e sem migração de banco. Reverter o commit restaura o contrato anterior. Não reverter ou apagar ledger para corrigir interface. Antes de habilitar sandbox externo: métricas de erros/latência, fila atrasada, retries/DLQ, discrepâncias, expiração de credenciais/certificados e alertas sem payloads pessoais. Manter produção sem rota de ativação enquanto não houver autorização expressa.

**Missão integral PENDENTE: este documento registra limites reais da implementação.**
