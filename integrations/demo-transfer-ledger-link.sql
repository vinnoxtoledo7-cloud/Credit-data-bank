-- Applied in Supabase sandbox.
alter table public.credit_account_ledger
  add column if not exists demo_transfer_id uuid
  references public.credit_demo_transfers(id);
create index if not exists idx_credit_ledger_demo_transfer
  on public.credit_account_ledger(demo_transfer_id)
  where demo_transfer_id is not null;
-- The existing credit_private.credit_demo_transfer(uuid,uuid,numeric,text)
-- SECURITY DEFINER implementation was updated to insert both ledger rows
-- with demo_transfer_id = v_transfer. Its other validation and locking
-- semantics remain unchanged. Deploy function definition from the live
-- database if recreating an environment.
-- Check reconciliation for NEW linked demo transfers:
select t.id,t.amount,count(l.id) entries,
  coalesce(sum(case when l.account_id=t.source_account_id then l.amount else 0 end),0) source_net,
  coalesce(sum(case when l.account_id=t.destination_account_id then l.amount else 0 end),0) destination_net
from public.credit_demo_transfers t
left join public.credit_account_ledger l on l.demo_transfer_id=t.id
group by t.id
having count(l.id)<>2
 or coalesce(sum(case when l.account_id=t.source_account_id then l.amount else 0 end),0)<>-t.amount
 or coalesce(sum(case when l.account_id=t.destination_account_id then l.amount else 0 end),0)<>t.amount;
-- Legacy transfers created before the schema change have no linked ledger ID.
-- Do not auto-backfill by description; manual verification is required.
