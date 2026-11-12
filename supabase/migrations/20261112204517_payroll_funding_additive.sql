-- Freeze approved inputs, debit only an owned sandbox account, persist payout snapshots.
create table credit_private.payroll_snapshots (
 batch_id uuid primary key references public.payroll_batches(id),
 items jsonb not null, total numeric(18,2) not null check(total>0), created_at timestamptz not null default now()
);
alter table credit_private.payroll_snapshots enable row level security;
revoke all on credit_private.payroll_snapshots from public,anon,authenticated;
alter table public.payroll_payment_simulations add column funding_account_id uuid references public.credit_accounts(id), add column ledger_id uuid references public.credit_account_ledger(id), add column item_snapshot jsonb;
create unique index payroll_unique_debit on public.payroll_payment_simulations(ledger_id) where ledger_id is not null;
do $$ declare d text; begin
 select pg_get_functiondef('credit_private.payroll_submit(uuid)'::regprocedure) into d;
 d:=replace(d,'update public.payroll_batches set status=', $s$
 insert into credit_private.payroll_snapshots(batch_id,items,total)
 select p_batch,jsonb_agg(jsonb_build_object('item_id',i.id,'employee_id',e.id,'name',e.full_name,'method',e.payment_method,'amount',i.net_amount) order by i.id),sum(i.net_amount)
 from public.payroll_batch_items i join public.payroll_employees e on e.id=i.employee_id and e.company_id=v_company where i.batch_id=p_batch;
 update public.payroll_batches set status=$s$);
 execute d;
end $$;
-- Existing unfunded simulations remain historical; never retrofit a debit.
create function credit_private.payroll_simulate_funded(p_batch uuid,p_account uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare b public.payroll_batches; s public.payroll_payment_simulations; snap credit_private.payroll_snapshots; entry uuid; result uuid; pix numeric; bank numeric;
begin
 if auth.uid() is null then raise exception 'Autenticação obrigatória'; end if;
 select * into b from public.payroll_batches where id=p_batch for update;
 if b.id is null or not exists(select 1 from public.payroll_companies where id=b.company_id and owner_id=auth.uid()) then raise exception 'Sem acesso ao lote'; end if;
 select * into s from public.payroll_payment_simulations where batch_id=p_batch;
 if found then
  if s.funding_account_id is distinct from p_account then raise exception 'Lote já simulado com outra origem ou sem débito histórico'; end if;
  return s.id;
 end if;
 if b.status<>'approved' then raise exception 'Dupla aprovação obrigatória'; end if;
 if b.payment_timing='scheduled' and b.scheduled_date>(now() at time zone 'America/Sao_Paulo')::date then raise exception 'Data agendada ainda não chegou'; end if;
 select * into snap from credit_private.payroll_snapshots where batch_id=p_batch;
 if not found then raise exception 'Lote histórico sem snapshot aprovado; requer revisão administrativa'; end if;
 if (select count(distinct actor_id) from public.payroll_approval_events where batch_id=p_batch and action in ('finance_approve','authorized_approve') and actor_id<>b.created_by)<>2 then raise exception 'Dupla aprovação segregada obrigatória'; end if;
 -- The reviewed entry implementation locks account before calculating the ledger balance.
 entry:=credit_private.credit_demo_entry(p_account,'demo_debit',snap.total,'Folha simulada '||p_batch::text);
 select coalesce(sum((i->>'amount')::numeric) filter(where i->>'method'='pix'),0),coalesce(sum((i->>'amount')::numeric) filter(where i->>'method'<>'pix'),0) into pix,bank from jsonb_array_elements(snap.items) i;
 insert into public.payroll_payment_simulations(batch_id,company_id,executed_by,item_count,total_amount,pix_amount,bank_amount,funding_account_id,ledger_id,item_snapshot)
 values(p_batch,b.company_id,auth.uid(),jsonb_array_length(snap.items),snap.total,pix,bank,p_account,entry,snap.items) returning id into result;
 insert into public.credit_audit_events(actor_id,action,entity_id,outcome) values(auth.uid(),'payroll_simulation',result,'success');
 return result;
end $$;
create function public.payroll_simulate_funded(p_batch uuid,p_account uuid) returns uuid language sql security invoker set search_path='' as $$ select credit_private.payroll_simulate_funded(p_batch,p_account) $$;
revoke all on function public.payroll_simulate_funded(uuid,uuid),credit_private.payroll_simulate_funded(uuid,uuid) from public,anon;
grant execute on function public.payroll_simulate_funded(uuid,uuid),credit_private.payroll_simulate_funded(uuid,uuid) to authenticated;

