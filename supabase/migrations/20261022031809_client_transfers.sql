-- Homologation only. No external payment provider is called.
create schema if not exists credit_private;
revoke all on schema credit_private from public, anon;
grant usage on schema credit_private to authenticated;
create table public.credit_beneficiaries (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id),
 account_id uuid not null references public.credit_accounts(id), nickname text not null check(length(trim(nickname)) between 2 and 80),
 recipient_name text not null, created_at timestamptz not null default now(), unique(owner_id,account_id)
);
create table public.credit_client_transfers (
 id uuid primary key default gen_random_uuid(), sender_id uuid not null references auth.users(id), recipient_id uuid not null references auth.users(id),
 source_account_id uuid not null references public.credit_accounts(id), destination_account_id uuid not null references public.credit_accounts(id),
 request_id uuid not null, amount numeric(18,2) not null check(amount>0 and amount<=1000000), description text not null,
 source_name text not null, destination_name text not null, created_at timestamptz not null default now(),
 environment text not null default 'homologacao' check(environment='homologacao'),
 check(sender_id<>recipient_id),check(source_account_id<>destination_account_id),unique(sender_id,request_id)
);
create table public.credit_audit_events (
 id uuid primary key default gen_random_uuid(), actor_id uuid not null references auth.users(id),
 action text not null, entity_id uuid, outcome text not null check(outcome in ('success','rejected')), reason text,
 created_at timestamptz not null default now()
);
alter table public.credit_account_ledger add column client_transfer_id uuid references public.credit_client_transfers(id);
create unique index credit_client_ledger_pair on public.credit_account_ledger(client_transfer_id,account_id) where client_transfer_id is not null;
create index credit_beneficiary_account on public.credit_beneficiaries(account_id);
create index credit_client_recipient on public.credit_client_transfers(recipient_id,created_at desc);
create index credit_client_sender on public.credit_client_transfers(sender_id,created_at desc);
create index credit_client_source on public.credit_client_transfers(source_account_id);
create index credit_client_destination on public.credit_client_transfers(destination_account_id);
create index credit_audit_actor on public.credit_audit_events(actor_id,created_at desc);
alter table public.credit_beneficiaries enable row level security;
alter table public.credit_client_transfers enable row level security;
alter table public.credit_audit_events enable row level security;
revoke all on public.credit_beneficiaries,public.credit_client_transfers,public.credit_audit_events from public,anon,authenticated;
grant select on public.credit_beneficiaries,public.credit_client_transfers,public.credit_audit_events to authenticated;
create policy beneficiary_owner on public.credit_beneficiaries for select to authenticated using(owner_id=(select auth.uid()));
create policy transfer_participants on public.credit_client_transfers for select to authenticated using(sender_id=(select auth.uid()) or recipient_id=(select auth.uid()));
create policy audit_actor on public.credit_audit_events for select to authenticated using(actor_id=(select auth.uid()));

create function credit_private.beneficiary_save(p_account uuid,p_nickname text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); a public.credit_accounts; bid uuid;
begin
 if u is null then raise exception 'Autenticação obrigatória'; end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 begin
 if (select count(*) from public.credit_audit_events where actor_id=u and action='beneficiary_save' and created_at>now()-interval '1 minute')>=20 then raise exception 'Aguarde um minuto antes de tentar novamente'; end if;
 if length(trim(coalesce(p_nickname,''))) not between 2 and 80 then raise exception 'Apelido deve ter entre 2 e 80 caracteres'; end if;
 select * into a from public.credit_accounts where id=p_account and status='sandbox' and currency='BRL';
 if a.id is null or a.owner_id=u then raise exception 'Conta de outro cliente não disponível para simulação'; end if;
 insert into public.credit_beneficiaries(owner_id,account_id,nickname,recipient_name) values(u,a.id,trim(p_nickname),a.display_name)
 on conflict(owner_id,account_id) do update set nickname=excluded.nickname,recipient_name=excluded.recipient_name returning id into bid;
 insert into public.credit_audit_events(actor_id,action,entity_id,outcome) values(u,'beneficiary_save',bid,'success');
 return jsonb_build_object('id',bid);
 exception when raise_exception then
 insert into public.credit_audit_events(actor_id,action,outcome,reason) values(u,'beneficiary_save','rejected',SQLERRM);
 return jsonb_build_object('error',SQLERRM);
 end;
end $$;
create function credit_private.beneficiary_remove(p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); bid uuid;
begin
 if u is null then raise exception 'Autenticação obrigatória'; end if;
 delete from public.credit_beneficiaries where id=p_id and owner_id=u returning id into bid;
 if bid is null then return jsonb_build_object('error','Beneficiário indisponível'); end if;
 insert into public.credit_audit_events(actor_id,action,entity_id,outcome) values(u,'beneficiary_remove',bid,'success');
 return jsonb_build_object('id',bid);
end $$;
create function credit_private.client_transfer(p_source uuid,p_beneficiary uuid,p_amount numeric,p_description text,p_request uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); b public.credit_beneficiaries; s public.credit_accounts; d public.credit_accounts;
 t public.credit_client_transfers; balance numeric; tid uuid;
begin
 if u is null then raise exception 'Autenticação obrigatória'; end if;
 -- Serializes request retries and per-user limits; account locks also serialize legacy ledger writes.
 perform pg_advisory_xact_lock(hashtextextended(u::text,0));
 begin
 if p_request is null or p_source is null or p_beneficiary is null then raise exception 'Dados obrigatórios ausentes'; end if;
 if p_amount is null or p_amount::text in ('NaN','Infinity','-Infinity') or p_amount<=0 or p_amount>1000000 or round(p_amount,2)<>p_amount then raise exception 'Valor inválido'; end if;
 if length(trim(coalesce(p_description,''))) not between 3 and 150 then raise exception 'Descrição deve ter entre 3 e 150 caracteres'; end if;
 select * into b from public.credit_beneficiaries where id=p_beneficiary and owner_id=u;
 if b.id is null then raise exception 'Beneficiário não autorizado'; end if;
 select * into t from public.credit_client_transfers where sender_id=u and request_id=p_request;
 if t.id is not null then
 if t.source_account_id<>p_source or t.destination_account_id<>b.account_id or t.amount<>p_amount or t.description<>trim(p_description) then raise exception 'Identificador já utilizado com outros dados'; end if;
 return jsonb_build_object('id',t.id,'replayed',true);
 end if;
 if (select count(*) from public.credit_audit_events where actor_id=u and action='client_transfer' and created_at>now()-interval '1 minute')>=20 then raise exception 'Limite de tentativas por minuto atingido'; end if;
 perform 1 from public.credit_accounts where id in(p_source,b.account_id) order by id for update;
 select * into s from public.credit_accounts where id=p_source;
 select * into d from public.credit_accounts where id=b.account_id;
 if s.id is null or s.owner_id<>u or s.status<>'sandbox' or s.currency<>'BRL' then raise exception 'Conta de origem não autorizada'; end if;
 if d.id is null or d.owner_id=u or d.status<>'sandbox' or d.currency<>'BRL' then raise exception 'Destino não autorizado'; end if;
 select coalesce(sum(amount),0) into balance from public.credit_account_ledger where account_id=s.id;
 if balance<p_amount then raise exception 'Saldo fictício insuficiente'; end if;
 insert into public.credit_client_transfers(sender_id,recipient_id,source_account_id,destination_account_id,request_id,amount,description,source_name,destination_name)
 values(u,d.owner_id,s.id,d.id,p_request,p_amount,trim(p_description),s.display_name,d.display_name) returning id into tid;
 insert into public.credit_account_ledger(account_id,amount,description,entry_type,client_transfer_id) values
 (s.id,-p_amount,'Transferência simulada enviada: '||trim(p_description),'demo_debit',tid),
 (d.id,p_amount,'Transferência simulada recebida: '||trim(p_description),'demo_credit',tid);
 insert into public.credit_audit_events(actor_id,action,entity_id,outcome) values(u,'client_transfer',tid,'success');
 return jsonb_build_object('id',tid,'replayed',false);
 exception when raise_exception then
 insert into public.credit_audit_events(actor_id,action,outcome,reason) values(u,'client_transfer','rejected',SQLERRM);
 return jsonb_build_object('error',SQLERRM);
 end;
end $$;
-- API wrappers remain invoker; privileged implementations are in a non-exposed schema.
create function public.credit_beneficiary_save(p_account uuid,p_nickname text) returns jsonb language sql security invoker set search_path='' as $$select credit_private.beneficiary_save(p_account,p_nickname)$$;
create function public.credit_beneficiary_remove(p_id uuid) returns jsonb language sql security invoker set search_path='' as $$select credit_private.beneficiary_remove(p_id)$$;
create function public.credit_client_transfer(p_source uuid,p_beneficiary uuid,p_amount numeric,p_description text,p_request uuid) returns jsonb language sql security invoker set search_path='' as $$select credit_private.client_transfer(p_source,p_beneficiary,p_amount,p_description,p_request)$$;
revoke all on all functions in schema credit_private from public,anon;
grant execute on all functions in schema credit_private to authenticated;
revoke all on function public.credit_beneficiary_save(uuid,text),public.credit_beneficiary_remove(uuid),public.credit_client_transfer(uuid,uuid,numeric,text,uuid) from public,anon;
grant execute on function public.credit_beneficiary_save(uuid,text),public.credit_beneficiary_remove(uuid),public.credit_client_transfer(uuid,uuid,numeric,text,uuid) to authenticated;
-- Server-side aggregation avoids incorrect balances beyond the REST row limit.
create function public.credit_account_balances() returns table(account_id uuid,balance numeric) language sql stable security invoker set search_path='' as $$
 select a.id,coalesce(sum(l.amount),0) from public.credit_accounts a left join public.credit_account_ledger l on l.account_id=a.id where a.owner_id=auth.uid() group by a.id
$$;
revoke all on function public.credit_account_balances() from public,anon;
grant execute on function public.credit_account_balances() to authenticated;
