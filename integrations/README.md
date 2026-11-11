# Integração BaaS: preparação segura

O sistema permanece **100% demonstrativo**. Nenhuma chamada cria contas ou movimenta fundos.

## Contratos implementados
- `baas-contract.js`: interface desacoplada, validação de intenção e bloqueio por padrão.
- `/api/baas/status`: endpoint somente leitura de disponibilidade.
- `/api/baas/transfers`: endpoint que recusa transferências reais (HTTP 503).

## Próximos passos antes de ativar qualquer operação
1. Confirmar fornecedor, contrato e documentação sandbox.
2. Criar credenciais **somente em secrets de servidor** e separar ambientes.
3. Verificar identidade e autorização de cada cliente no backend, com KYC/KYB do parceiro.
4. Persistir intenção e chave de idempotência em transação atômica, sem confiar no cliente.
5. Validar assinatura e timestamp de webhook conforme especificação do fornecedor; aplicar replay protection.
6. Implementar máquina de estados, conciliação e trilha de auditoria imutável.
7. Exigir autenticação reforçada e limites para operações sensíveis.
8. Testar falhas, duplicações, timeouts, reversões, isolamento PF/PJ e RLS antes de homologação.

Não utilizar o saldo fictício do sistema como fonte de verdade financeira. Não ativar produção apenas pela presença de credenciais.
