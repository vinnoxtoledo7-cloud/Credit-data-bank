# Credit Data Bank Dark Premium v3 | Homologação

Interface premium escura, responsiva, com painel PF/PJ, login Supabase, cadastros e administração preservados da v2.

## Credit AI
O módulo **Credit AI** nesta versão é um assistente **guiado, com perguntas e respostas fixas**. Não há integração com um modelo de IA generativa, nem envio de perguntas a APIs externas. Uma futura integração exigirá backend protegido, política de dados e controles de custo e segurança.

## Instalação
Envie os cinco arquivos descompactados para a raiz do repositório conectado à Vercel. Mantenha a configuração de Supabase e teste login, perfis e permissões em homologação.

## Aviso
Nenhum saldo, Pix, transferência, cartão ou limite exibido corresponde a um serviço financeiro real. Não usar dados sensíveis de clientes reais para testes.

## Segurança e validação de homologação

As RPCs privilegiadas ficam em `credit_private`, com interfaces públicas SECURITY INVOKER e controles explícitos de autenticação/titularidade. Consulte [o relatório de segurança](docs/relatorio-seguranca-homologacao.md) para resultados e pendências. As suítes SQL estão em `tests/legacy-security.sql` e `tests/client-transfers.sql` e revertem os dados temporários.
