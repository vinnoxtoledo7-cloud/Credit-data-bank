# Credit Data Bank — reforço de segurança em homologação

Data: 22/10/2026. Projeto Supabase: jruspbiljejmknjvnesd.

## Concluído

- Revisão das seis RPCs antigas: lançamentos fictícios, transferências próprias, envio de folha, atribuição de aprovadores, aprovação e simulação de pagamento.
- Implementações privilegiadas movidas para o schema não exposto `credit_private`, com `search_path` vazio e verificação explícita de autenticação. Os endpoints públicos preservam assinaturas e usam SECURITY INVOKER.
- Permissão de execução negada a PUBLIC e anon; uso autenticado continua sujeito às verificações de titularidade e de papel dentro de cada implementação.
- Validação explícita de tipos/perfis nulos e valores numéricos não finitos.
- Migração aplicada no Supabase. Nenhuma integração com dinheiro real foi adicionada.

## Testes executados

`tests/legacy-security.sql` passou primeiro com a migração em uma transação revertida e depois após sua aplicação definitiva:

- Rejeição sem autenticação nas seis funções.
- Crédito fictício e transferência entre contas próprias; saldo final conferido.
- Rejeição de tipo nulo, NaN, saldo insuficiente e acesso a conta de outro titular.
- Atribuição de aprovadores apenas pelo responsável da empresa.
- Envio de folha, aprovação financeira e aprovação pelo responsável.
- Bloqueio da segunda aprovação pela mesma pessoa.
- Bloqueio de simulação antes da dupla aprovação, por outro usuário e em duplicidade.
- Simulação autorizada com total correto.
- Verificação de permissões de execução e ausência de SECURITY DEFINER no schema público.

`tests/client-transfers.sql` passou novamente: beneficiários, transferências entre clientes, idempotência, saldos, políticas de acesso, registros imutáveis para clientes, auditoria e limites.

Todos os dados criados por essas suítes SQL foram revertidos com ROLLBACK. O teste HTTP da etapa anterior também passou com dois usuários e operações concorrentes; suas contas temporárias foram removidas na etapa anterior.

## Verificador de segurança

Antes: seis avisos de funções privilegiadas expostas e um aviso de proteção contra senhas vazadas desativada.
Depois: apenas o aviso de proteção contra senhas vazadas permanece. A ausência dos seis avisos não equivale a uma auditoria independente completa; as funções privadas continuam privilegiadas por necessidade e mantêm controles explícitos de autorização.

## Pendências e limites

- Ativar a proteção contra senhas vazadas nas configurações de Auth do Supabase, conforme disponibilidade do plano. A integração conectada não expõe leitura/alteração dessa configuração. Documentação: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- Teste visual autenticado de todos os fluxos continua pendente: o navegador local não pôde ser instalado. Na etapa anterior, a tela pública publicada foi aberta no navegador remoto e o fluxo autenticado foi validado pela API, não pela interface completa.
- A consulta administrativa com o identificador do time Vercel retornou 403 na etapa anterior. Isso não foi contornado. As alterações desta etapa são de banco, testes e documentação; não alteram a interface publicada.
- As migrações deste repositório pressupõem o esquema preexistente do projeto; não constituem ainda um bootstrap completo de um banco vazio.

## Como repetir os testes

Executar cada arquivo SQL completo em uma sessão conectada ao banco de homologação, com uma função administrativa capaz de criar os dados temporários. Os testes mudam para o papel `authenticated` nas verificações de autorização e terminam com ROLLBACK. Não executar em produção.
