begin;
insert into auth.users(id,email) values ('99000000-0000-4000-8000-000000000001','atomic-qa@example.invalid');
insert into public.credit_accounts(id,owner_id,account_type,display_name) values
('99000000-0000-4000-8000-000000000002','99000000-0000-4000-8000-000000000001','PF','QA atomic source'),
('99000000-0000-4000-8000-000000000003','99000000-0000-4000-8000-000000000001','PJ','QA atomic target');
-- The temporary trigger fails ONLY the disposable destination's credit.
create function pg_temp.fail_qa_credit() returns trigger language plpgsql as $$begin
 if new.account_id='99000000-0000-4000-8000-000000000003' and new.amount>0 then raise exception 'QA injected credit failure';end if;return new;end $$;
create trigger qa_atomic_failure before insert on public.credit_account_ledger for each row execute function pg_temp.fail_qa_credit();
set local role authenticated;
select set_config('request.jwt.claim.sub','99000000-0000-4000-8000-000000000001',true);
select public.credit_demo_entry('99000000-0000-4000-8000-000000000002','demo_credit',100,'QA initial');
do $$ declare rejected boolean:=false;begin
 begin perform public.credit_demo_transfer_idempotent('99000000-0000-4000-8000-000000000002','99000000-0000-4000-8000-000000000003',50,'QA failure',gen_random_uuid());exception when raise_exception then if sqlerrm<>'QA injected credit failure' then raise;end if;rejected:=true;end;
 if not rejected then raise exception 'Failure not injected';end if;
 if (select count(*) from public.credit_demo_transfers where owner_id=auth.uid())<>0 then raise exception 'Orphan transfer';end if;
 if (select sum(amount) from public.credit_account_ledger where account_id='99000000-0000-4000-8000-000000000002')<>100 then raise exception 'Partial debit persisted';end if;
 begin perform public.credit_reconciliation_report();raise exception 'Missing admin guard';exception when raise_exception then if sqlerrm<>'Acesso administrativo obrigatório' then raise;end if;end;
end $$;
reset role;
insert into public.admin_members(user_id) values('99000000-0000-4000-8000-000000000001');
set local role authenticated;
do $$ declare r jsonb;begin r:=public.credit_reconciliation_report();if jsonb_typeof(r->'findings')<>'array' then raise exception 'Invalid report';end if;end $$;
rollback;
select 'PASS: injected credit failure rolls back debit and transfer; reconciliation enforces admin access; fixtures and trigger rolled back' result;
