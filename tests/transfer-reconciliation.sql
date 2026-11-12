-- Read-only reconciliation of inter-client sandbox transfers.
-- Each client transfer must have exactly one debit and one credit, linked by transfer ID.
with reconciled as (
 select t.id,t.amount,t.source_account_id,t.destination_account_id,
        count(l.id) as ledger_entries,
        coalesce(sum(case when l.account_id=t.source_account_id then l.amount else 0 end),0) as source_net,
        coalesce(sum(case when l.account_id=t.destination_account_id then l.amount else 0 end),0) as destination_net
 from public.credit_client_transfers t
 left join public.credit_account_ledger l on l.client_transfer_id=t.id
 group by t.id
)
select id,amount,ledger_entries,source_net,destination_net
from reconciled
where ledger_entries<>2 or source_net<>-amount or destination_net<>amount;
-- Expected: zero rows, but also verify transfer count > 0 to avoid vacuous success.
select count(*) as transfer_count from public.credit_client_transfers;
-- Demo transfers do not currently have a transfer_id FK in the ledger;
-- their reconciliation cannot be proven by this query.
-- Recommended next schema improvement: link demo ledger entries to demo transfer ID.
