-- Run in Supabase SQL editor. Uses existing sandbox account, no persisted financial changes.
-- Replace the account and owner UUIDs with a valid pair in your test environment.
begin;
select set_config('request.jwt.claim.sub','16e43329-e230-468b-ac8d-94c6565c8a77',true);
set local role authenticated;
create temp table test_results(name text,passed boolean) on commit drop;
do $$
declare a uuid:='2bb42dd0-d30a-43e9-bca9-2e0a9dddd54b'; req uuid:=gen_random_uuid(); first_id uuid; second_id uuid; before_count int; after_count int; before_balance numeric; after_balance numeric; rejected boolean:=false;
begin
select count(*),coalesce(sum(amount),0) into before_count,before_balance from public.credit_account_ledger where account_id=a;
first_id:=public.credit_demo_entry_idempotent(a,'demo_credit',1.23,'Teste automatizado rollback',req);
second_id:=public.credit_demo_entry_idempotent(a,'demo_credit',1.23,'Teste automatizado rollback',req);
select count(*),coalesce(sum(amount),0) into after_count,after_balance from public.credit_account_ledger where account_id=a;
insert into test_results values('same request returns same ledger id',first_id=second_id),('single ledger entry for replay',after_count=before_count+1),('balance increases exactly once',after_balance=before_balance+1.23);
begin
perform public.credit_demo_entry_idempotent(a,'demo_credit',2.34,'Teste automatizado rollback',req);
exception when others then rejected:=true;
end;
insert into test_results values('request reuse with different amount rejected',rejected);
end $$;
select * from test_results;
rollback;
