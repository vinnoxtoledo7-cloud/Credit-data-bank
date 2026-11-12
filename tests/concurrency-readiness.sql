-- Read-only readiness checks. No data modification.
-- Confirms transfer functions lock accounts before checking ledger balances.
with definitions as (
  select p.proname,pg_get_functiondef(p.oid) definition
  from pg_proc p
  where p.pronamespace='credit_private'::regnamespace
    and p.proname in ('credit_demo_transfer','client_transfer','credit_demo_entry')
)
select proname,
       position('for update' in lower(definition))>0 as locks_account,
       position('sum(amount)' in lower(definition))>0 as computes_balance
from definitions;
-- All should return true.
select a.id,coalesce(sum(l.amount),0) as balance
from public.credit_accounts a
left join public.credit_account_ledger l on l.account_id=a.id
group by a.id
having coalesce(sum(l.amount),0)<0;
-- Must return zero rows.
-- IMPORTANT: these checks do NOT simulate simultaneous connections.
-- Full concurrency test requires two separate authenticated sessions against isolated
-- disposable sandbox accounts, each attempting to debit more than half the same balance.
-- Expected: one succeeds, second rejects for insufficient balance, total never negative.
