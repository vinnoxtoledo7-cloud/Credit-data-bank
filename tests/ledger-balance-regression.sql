-- Regression test: replace account/owner UUIDs for other environments.
-- Always rolls back.
begin;
select set_config('request.jwt.claim.sub','16e43329-e230-468b-ac8d-94c6565c8a77',true);
set local role authenticated;
create temp table results(name text,passed boolean) on commit drop;
do $$
declare a uuid:='2bb42dd0-d30a-43e9-bca9-2e0a9dddd54b'; b uuid:='285ac901-6f1c-4393-80c8-af1293f56153'; x numeric;y numeric; z numeric; rejected boolean:=false;
begin
select coalesce(sum(amount),0) into x from public.credit_account_ledger where account_id=a;
select coalesce(sum(amount),0) into y from public.credit_account_ledger where account_id=b;
begin
perform public.credit_demo_entry_idempotent(a,'demo_debit',x+1,'Teste saldo insuficiente',gen_random_uuid());
exception when others then rejected:=true;
end;
insert into results values('insufficient balance rejected',rejected);
perform public.credit_demo_transfer(a,b,1,'Teste transferencia rollback');
select coalesce(sum(amount),0) into z from public.credit_account_ledger where account_id=a;
insert into results values('source debited once',z=x-1);
select coalesce(sum(amount),0) into z from public.credit_account_ledger where account_id=b;
insert into results values('destination credited once',z=y+1);
insert into results values('total preserved',(select coalesce(sum(amount),0) from public.credit_account_ledger where account_id in (a,b))=x+y);
end $$;
select * from results;
rollback;
