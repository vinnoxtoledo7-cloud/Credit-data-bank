# Preparação Celcoin — sem ativação financeira

Consulta à documentação oficial em 12/11/2026. O produto aplicável é cel_banking/BaaS com onboarding PF/PJ, contas, Pix/transferências, saldo, extrato e eventos conforme escopo contratado. Não há contrato ou credenciais do parceiro configurados neste aplicativo.

## Dependências externas

- **PENDENTE — contrato:** confirmar BaaS e cada produto habilitado, modelo de conta, titularidade, limites, preços e responsabilidades. Não presumir que TED, Pix, cartões ou onboarding fazem parte do pacote.
- **PENDENTE — autenticação:** documentação informa OAuth 2.0 e client_credentials; produção também exige certificado mTLS e liberação prévia de IPs. Solicitar credenciais sandbox para o produto/CNPJ ao parceiro. Não reutilizar exemplos de credenciais publicados em documentação.
- **PENDENTE — infraestrutura:** validar egress fixo, armazenamento/rotação do certificado, segurança de tokens e suporte da hospedagem. Nenhuma contratação foi feita.
- **PENDENTE — homologação Celcoin:** testes feitos na aplicação, evidências com identificadores e roteiro do produto contratado; aprovação técnica precede validações contratuais e liberação de credenciais produtivas.
- **PENDENTE — jurídico/compliance:** advogado especializado e parceiro devem definir deveres regulatórios, LGPD, KYC/KYB, PLD, atendimento, incidentes e continuidade. Código não comprova conformidade.

## Contratos a implementar e verificar

- Onboarding: propostas PF/PJ, estados assíncronos e retorno por webhook; fluxos de background check, webview de documentação e criação de conta dependem do produto contratado. Não confundir cadastro local aprovado com conta externa aberta.
- Contas externas: mapear ID interno, provedor, ambiente e referência externa com unicidade. Não misturar identificadores sandbox/produção.
- Transferências: armazenar intenção/idempotência, enviar por backend, reconciliar status antes de declarar conclusão; divergência gera investigação. Contrato mock atual não envia Pix/TED.
- Webhooks: validar mecanismo de autenticação **específico do produto e versão contratados**, corpo bruto, replay e duplicidade. Não presumir que a assinatura HMAC do mock seja aceita pela Celcoin. Campos adicionais devem ser tolerados; eventos não substituem a consulta oficial de extrato.
- Inbox/outbox duráveis: unique(provider,event_id), hash do payload, tentativas, lease, dead-letter, rastreabilidade e acesso operacional restrito. O worker em memória atual serve só para testes de contrato.
- Conciliação externa: consultar extrato do parceiro como fonte de suas movimentações; comparar referências/valores/status com ledger interno. Não construir extrato externo exclusivamente a partir de webhook.
- Liberação produtiva: exigirá nova autorização expressa do proprietário, contrato, homologação aprovada, credenciais e revisão independente. Nenhum toggle atual deve habilitar produção.

## Fontes oficiais

1. [Integração BaaS](https://suporte.celcoin.com.br/hc/pt-br/articles/10114393814171-Como-integrar-a-minha-empresa-com-a-solu%C3%A7%C3%A3o-BaaS-da-Celcoin)
2. [Credenciais de acesso](https://developers.celcoin.com.br/docs/obtendo-acesso-%C3%A0s-apis)
3. [Instruções para homologar](https://developers.celcoin.com.br/docs/homologacao-celcoin)
4. [Criação de contas / onboarding](https://developers.celcoin.com.br/docs/utilizacao-do-onboarding-celcoin)
5. [Gerenciamento de webhooks](https://developers.celcoin.com.br/docs/gerenciamento-de-webhook)

Revalidar contratos de API e roteiros com o analista Celcoin na contratação. Não foram executadas chamadas financeiras, cadastrados webhooks Celcoin ou usados endpoints produtivos.
