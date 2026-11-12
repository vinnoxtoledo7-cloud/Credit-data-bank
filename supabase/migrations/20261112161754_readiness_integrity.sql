-- Additive homologation hardening. No historical financial rows are rewritten.
revoke all on public.payroll_companies, public.payroll_employees, public.payroll_batches, public.payroll_batch_items, public.payroll_approvers, public.payroll_approval_events from anon;
revoke truncate, references, trigger on public.customer_profiles, public.payroll_companies, public.payroll_employees, public.payroll_batches, public.payroll_batch_items, public.payroll_approvers, public.payroll_approval_events from authenticated;
revoke insert,update,delete on public.payroll_approvers,public.payroll_approval_events from authenticated;
alter table credit_private.demo_entry_requests enable row level security;
revoke all on credit_private.demo_entry_requests from public,anon,authenticated;
-- Retain signature, move privileged implementation outside the exposed schema.
do $$ declare d text; begin
 select pg_get_functiondef('public.credit_demo_entry_idempotent(uuid,text,numeric,text,uuid)'::regprocedure) into d;
 execute replace(d,'FUNCTION public.credit_demo_entry_idempotent(','FUNCTION credit_private.credit_demo_entry_idempotent(');
end $$;
create or replace function public.credit_demo_entry_idempotent(p_account uuid,p_kind text,p_amount numeric,p_description text,p_request uuid) returns uuid language sql security invoker set search_path='' as $$ select credit_private.credit_demo_entry_idempotent(p_account,p_kind,p_amount,p_description,p_request) $$;
revoke all on function credit_private.credit_demo_entry_idempotent(uuid,text,numeric,text,uuid) from public,anon;
grant execute on function credit_private.credit_demo_entry_idempotent(uuid,text,numeric,text,uuid) to authenticated;

alter table public.credit_demo_transfers add column request_id uuid;
create unique index credit_demo_request_unique on public.credit_demo_transfers(owner_id,request_id) where request_id is not null;
create function credit_private.demo_transfer_idempotent(p_source uuid,p_destination uuid,p_amount numeric,p_description text,p_request uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t public.credit_demo_transfers; result uuid;
begin
 if u is null then raise exception 'Autenticação obrigatória'; end if;
 if p_request is null then raise exception 'Identificador obrigatório'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text||':'||p_request::text,0));
 select * into t from public.credit_demo_transfers where owner_id=u and request_id=p_request;
 if found then
  if t.source_account_id is distinct from p_source or t.destination_account_id is distinct from p_destination or t.amount is distinct from p_amount or t.description is distinct from trim(p_description) then raise exception 'Identificador já utilizado com outros dados'; end if;
  return t.id;
 end if;
 result:=credit_private.credit_demo_transfer(p_source,p_destination,p_amount,p_description);
 update public.credit_demo_transfers set request_id=p_request where id=result;
 insert into public.credit_audit_events(actor_id,action,entity_id,outcome) values(u,'demo_transfer',result,'success');
 return result;
end $$;
create function public.credit_demo_transfer_idempotent(p_source uuid,p_destination uuid,p_amount numeric,p_description text,p_request uuid) returns uuid language sql security invoker set search_path='' as $$ select credit_private.demo_transfer_idempotent(p_source,p_destination,p_amount,p_description,p_request) $$;
revoke all on function public.credit_demo_transfer_idempotent(uuid,uuid,numeric,text,uuid),credit_private.demo_transfer_idempotent(uuid,uuid,numeric,text,uuid) from public,anon;
grant execute on function public.credit_demo_transfer_idempotent(uuid,uuid,numeric,text,uuid),credit_private.demo_transfer_idempotent(uuid,uuid,numeric,text,uuid) to authenticated;

-- Lock the same batch as submit/approve; prohibit moving an item to another batch.
create or replace function public.payroll_block_item_changes() returns trigger language plpgsql set search_path='' as $$
declare b uuid; s text;
begin
 if tg_op='UPDATE' and (old.batch_id<>new.batch_id or old.employee_id<>new.employee_id) then raise exception 'Vínculo do lançamento imutável'; end if;
 b:=case when tg_op='DELETE' then old.batch_id else new.batch_id end;
 select status into s from public.payroll_batches where id=b for update;
 if s is distinct from 'draft' then raise exception 'Folha bloqueada após envio'; end if;
 return case when tg_op='DELETE' then old else new end;
end $$;
-- Enforce three distinct participants: creator, finance approver, final approver.
do $$ declare d text; begin
 select pg_get_functiondef('credit_private.payroll_approve(uuid)'::regprocedure) into d;
 d:=replace(d,'if v_status=''pending_finance''', 'if exists(select 1 from public.payroll_batches where id=p_batch and created_by=auth.uid()) then raise exception ''Criador não pode aprovar a própria folha''; end if; if v_status=''pending_finance''');
 execute d;
end $$;

-- A participant may inspect both linked ledger IDs without reading other account history.
create function credit_private.transfer_receipt(p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); t record; rows jsonb; n int; debits int; credits int;
begin
 if u is null then raise exception 'Autenticação obrigatória'; end if;
 select id,source_account_id,destination_account_id,amount,description,created_at,source_name,destination_name,'client'::text kind into t from public.credit_client_transfers where id=p_id and u in (sender_id,recipient_id);
 if not found then
  select x.id,x.source_account_id,x.destination_account_id,x.amount,x.description,x.created_at,a.display_name source_name,b.display_name destination_name,'own'::text kind into t from public.credit_demo_transfers x join public.credit_accounts a on a.id=x.source_account_id join public.credit_accounts b on b.id=x.destination_account_id where x.id=p_id and x.owner_id=u;
 end if;
 if not found then raise exception 'Operação não autorizada'; end if;
 select count(*),count(*) filter(where account_id=t.source_account_id and amount=-t.amount),count(*) filter(where account_id=t.destination_account_id and amount=t.amount),coalesce(jsonb_agg(jsonb_build_object('id',id,'account_id',account_id,'amount',amount) order by amount),'[]') into n,debits,credits,rows from public.credit_account_ledger where client_transfer_id=p_id or demo_transfer_id=p_id;
 return to_jsonb(t)||jsonb_build_object('environment','homologacao','ledger',rows,'reconciled',n=2 and debits=1 and credits=1,'status',case when n=2 and debits=1 and credits=1 then 'confirmed' else 'reconciliation_pending' end);
end $$;
create function public.credit_transfer_receipt(p_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select credit_private.transfer_receipt(p_id) $$;
revoke all on function public.credit_transfer_receipt(uuid),credit_private.transfer_receipt(uuid) from public,anon;
grant execute on function public.credit_transfer_receipt(uuid),credit_private.transfer_receipt(uuid) to authenticated;

create function credit_private.reconciliation_report() returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null or not exists(select 1 from public.admin_members where user_id=auth.uid()) then raise exception 'Acesso administrativo obrigatório'; end if;
 with transfers as (
 select id,source_account_id,destination_account_id,amount,'own' kind from public.credit_demo_transfers
 union all select id,source_account_id,destination_account_id,amount,'client' from public.credit_client_transfers
 ), findings as (
 select t.id,t.kind,'transfer_ledger_mismatch' issue from transfers t left join public.credit_account_ledger l on l.demo_transfer_id=t.id or l.client_transfer_id=t.id group by t.id,t.kind,t.source_account_id,t.destination_account_id,t.amount having count(l.id)<>2 or count(*) filter(where l.account_id=t.source_account_id and l.amount=-t.amount)<>1 or count(*) filter(where l.account_id=t.destination_account_id and l.amount=t.amount)<>1
 union all select account_id,'account','negative_balance' from public.credit_account_ledger group by account_id having sum(amount)<0
 union all select id,'ledger','multiple_transfer_references' from public.credit_account_ledger where client_transfer_id is not null and demo_transfer_id is not null
 ) select coalesce(jsonb_agg(to_jsonb(findings)),'[]') into result from findings;
 insert into public.credit_audit_events(actor_id,action,outcome) values(auth.uid(),'reconciliation_read','success');
 return jsonb_build_object('checked_at',now(),'environment','homologacao','findings',result,'balance_source','ledger_sum','historical_adjustments',false);
end $$;
create function public.credit_reconciliation_report() returns jsonb language sql security invoker set search_path='' as $$ select credit_private.reconciliation_report() $$;
revoke all on function public.credit_reconciliation_report(),credit_private.reconciliation_report() from public,anon;
grant execute on function public.credit_reconciliation_report(),credit_private.reconciliation_report() to authenticated;
