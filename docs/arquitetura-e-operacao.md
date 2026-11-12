# Arquitetura e operação

## 1. Camadas e limites

Interface estática HTML/JS na Vercel; Supabase Auth identifica o usuário; RLS e RPCs Postgres autorizam operações; ledger é fonte dos saldos. APIs `/api/baas` operam com identidade do chamador, sem service role. BaaS produtivo e webhooks públicos permanecem bloqueados com 503. `integrations/mock-baas.js` é somente contrato de testes em memória, sem chamadas de rede.

## 2. Banco e permissões

`auth.users` é identidade, `customer_profiles` é cadastro PF/PJ, `credit_accounts` é conta fictícia. A vinculação formal perfil-conta ainda precisa ser implementada. `admin_members` controla administradores e não tem escrita de cliente. `credit_private` guarda implementações privilegiadas; wrappers públicos usam invoker, search_path vazio e grants explícitos. RLS limita tabelas financeiras ao titular/participantes. `baas_private` não possui políticas de cliente; ausência de políticas é intencional para negar acesso.

Não conceder privilégios por metadados editáveis do usuário. Toda nova função definer precisa verificar `auth.uid()`, recursos, estados, limites e grants. Nenhuma chave administrativa pode ir ao frontend. Revisar o diff e o advisor depois de cada migração. Arquivos antigos em integrations não representam, isoladamente, o estado aplicado: conferir `supabase_migrations.schema_migrations`.

## 3. Abertura de contas

Cadastro e aprovação são demonstrativos; não criam conta financeira real. PF/PJ atualmente possuem rascunho/envio/aprovação/recusa. O estado under_review existe no schema mas o fluxo integral ainda requer correção. `sandbox_account_requests` registra pedido com proprietário e perfil conferidos por RLS. Validação documental, representantes, KYC/KYB e consentimentos não estão concluídos.

## 4. Saldos, transferências e concorrência

Saldo = SUM(ledger.amount); navegador não atualiza saldo diretamente. RPCs travam contas por ordem de UUID antes de verificar disponibilidade e inserir lançamentos. Mesma transação grava transferência, débito e crédito. Funções idempotentes travam a chave por usuário, conferem payload e reutilizam o resultado; mudar payload usando a mesma chave é erro. A UI mantém chave em sessionStorage para respostas de rede incertas. Crédito fictício de teste continua permitido em contas próprias: não representa depósito.

Transferência entre clientes usa beneficiário previamente salvo e valida titularidade, limite por operação e frequência. Operações rejeitadas desse fluxo são auditadas. Fluxo legado de transferência própria sem chave ainda existe por compatibilidade: não deve ser usado por novas interfaces. Testes de concorrência precisam de sessões HTTP independentes; verificar texto de função não é teste de concorrência.

## 5. Conciliação e comprovantes

A consulta `credit_transfer_receipt` autoriza participantes e confere os dois lançamentos antes de declarar status confirmado. PDF inclui aviso obrigatório, IDs, contas, nomes disponíveis, data de registro, valor fictício e resultado de conciliação. Nome de exibição de conta não equivale a identidade legal verificada. Relatório central só pode ser consultado por admin e registra evento de auditoria. Divergências históricas devem ser investigadas; nenhum ajuste automático está habilitado. Futuro ajuste deve exigir justificativa, ator, autorização forte e lançamento compensatório, preservando histórico.

## 6. Payroll

Empresas, funcionários, lotes, itens, aprovadores, eventos e simulações são separados. Lote sai de draft para pending_finance, pending_authorized e approved. As duas aprovações exigem pessoas diferentes e excluem o criador. Mutação de itens e envio travam o mesmo lote. A simulação legada ainda NÃO debita saldo: não tratá-la como pagamento concluído. A proposta financiada em `docs/pending` precisa ser aplicada e testada antes da troca do fluxo. Não atribuir débito retroativo a simulações antigas. Importação atual é CSV; Excel permanece pendente.

## 7. BaaS, estados e webhooks

Contrato de provedor suporta onboarding, conta, saldo, extrato e transferência; estado padrão unconfigured/disabled. Adaptador mock cobre apenas transferência e retorna pending. Inbox mock verifica HMAC SHA-256 do corpo bruto + timestamp, janela temporal, tamanho e eventos duplicados; conflito de mesmo evento com outro hash é erro. Falhas permitem três tentativas antes de dead-letter. Isso é um protocolo de teste interno, **não a especificação Celcoin**. Armazenamento em memória não é durável e não está exposto em endpoint. Inbox/outbox Postgres, worker com lease, dead-letter operacional e reconciliação externa ainda precisam de implementação.

## 8. Variáveis e segredos

APIs aceitam SUPABASE_URL ou VITE_SUPABASE_URL; SUPABASE_PUBLISHABLE_KEY, SUPABASE_ANON_KEY ou VITE_SUPABASE_PUBLISHABLE_KEY. Apenas URL/chave pública são usadas. Nunca imprimir access/refresh tokens, senhas, chaves administrativas, certificados ou segredos de webhook. Não configurar credenciais Celcoin agora. Segredos futuros somente em backend com escopo por ambiente, rotação, auditoria e expiração; egress/mTLS precisam ser avaliados para o plano de hospedagem contratado.

## 9. Backup, restauração e continuidade

PENDENTE: confirmar política e retenção efetivamente contratadas no Supabase, RPO/RTO e responsabilidade operacional. Antes de alteração destrutiva: backup lógico criptografado de schema/dados/roles, inventário de Storage e configuração Auth; validar restauração em ambiente isolado autorizado, comparar contagens, constraints, RLS e testes financeiros, registrar duração e evidências. Não restaurar por cima do projeto ativo. Backups podem conter dados pessoais e precisam de acesso mínimo e descarte controlado. Git não é backup dos dados. Rollback de frontend via deployment estável é separado de rollback de banco; preferir migrações corretivas aditivas, nunca apagar ledger.

## 10. Plano de testes e homologação

`node --test tests/*.test.mjs` na CI. SQL rollback: client-transfers, legacy-security, atomic-failure. HTTP: financial-concurrency com QA_USERS_FILE fora do repositório, usuários exclusivamente descartáveis e logout no finally. Após teste, limpar apenas IDs e marcador de QA com aprovação da integração. Nunca executar os antigos testes com IDs de clientes existentes: adaptar para fixtures primeiro.

PENDENTE: suíte PF/PJ, suspensão, folha financiada/Excel/cancelamento, MFA, e-mail recovery end-to-end, sessão/cookies, mobile/tablet e falhas de rede via UI. `browser-flow.cjs` existe mas não foi executado nesta entrega; usar apenas mecanismo de navegador autorizado e credenciais de teste. Deploy somente com evidência dos testes relativos ao incremento; não interpretar publicação como aprovação da homologação completa.

## 11. LGPD, termos e incidentes

PENDENTE de jurídico/encarregado: inventário/controlador-operador, bases legais por finalidade (consentimento não é base universal), política de privacidade, versão de termos, prova de aceite, retenção/descarte, direitos dos titulares, suboperadores e transferência internacional. Não publicar textos como conformes sem revisão.

PENDENTE de parceiro/compliance: KYC/KYB, beneficiário final, representantes/procurações, PEP/sanções, classificação de risco e monitoramento PLD, tratamento de alertas e comunicação aplicável. Não automatizar decisão financeira real. Incidentes exigem contenção, preservação de evidências, revogação de sessões/segredos, avaliação de impacto e decisão de comunicação por responsáveis; testar recuperação e continuidade. Registrar fornecedores, contratos, SLA, suporte, plano de saída e responsabilidade por dados.
