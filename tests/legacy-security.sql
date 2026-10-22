begin;
create function pg_temp.expect_error(q text, expected text) returns void language plpgsql as $$
begin
 begin execute q; exception when others then
 if position(expected in SQLERRM)=0 then raise exception 'Unexpected error: % (expected %)',SQLERRM,expected;end if;return;
 end;
 raise exception 'Expected failure but succeeded: %',q;
end $$;
insert into auth.users(id,email,email_confirmed_at) values
('11000000-0000-4000-8000-000000000001','qa-owner@example.invalid',now()),
('11000000-0000-4000-8000-000000000002','qa-finance@example.invalid',now()),
('11000000-0000-4000-8000-000000000003','qa-authorizer@example.invalid',now());
insert into public.credit_accounts(id,owner_id,account_type,display_name) values
('21000000-0000-4000-8000-000000000001','11000000-0000-4000-8000-000000000001','PF','QA source'),
('21000000-0000-4000-8000-000000000002','11000000-0000-4000-8000-000000000001','PJ','QA destination');
insert into public.payroll_companies(id,owner_id,name) values('41000000-0000-4000-8000-000000000001','11000000-0000-4000-8000-000000000001','QA payroll');
insert into public.payroll_employees(id,company_id,full_name) values('51000000-0000-4000-8000-000000000001','41000000-0000-4000-8000-000000000001','QA employee');
insert into public.payroll_batches(id,company_id,competence,created_by) values('61000000-0000-4000-8000-000000000001','41000000-0000-4000-8000-000000000001','2026-10','11000000-0000-4000-8000-000000000001');
insert into public.payroll_batch_items(batch_id,employee_id,net_amount) values('61000000-0000-4000-8000-000000000001','51000000-0000-4000-8000-000000000001',100);
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select pg_temp.expect_error('select public.payroll_approve(null)','Autenticação obrigatória');
select pg_temp.expect_error('select public.payroll_assign_approver(null,null,null)','Autenticação obrigatória');
select pg_temp.expect_error('select public.payroll_submit(null)','Autenticação obrigatória');
select pg_temp.expect_error('select public.payroll_simulate_payment(null)','Autenticação obrigatória');
select pg_temp.expect_error('select public.credit_demo_entry(null,null,null,null)','Autenticação obrigatória');
select pg_temp.expect_error('select public.credit_demo_transfer(null,null,null,null)','Autenticação obrigatória');
select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000001',true);
select public.credit_demo_entry('21000000-0000-4000-8000-000000000001','demo_credit',100,'QA credit');
select public.credit_demo_transfer('21000000-0000-4000-8000-000000000001','21000000-0000-4000-8000-000000000002',25,'QA transfer');
select pg_temp.expect_error($q$select public.credit_demo_entry('21000000-0000-4000-8000-000000000001',null,1,'QA bad')$q$,'Valor ou tipo inválido');
select pg_temp.expect_error($q$select public.credit_demo_entry('21000000-0000-4000-8000-000000000001','demo_debit',76,'QA bad')$q$,'Saldo fictício insuficiente');
select pg_temp.expect_error($q$select public.credit_demo_transfer('21000000-0000-4000-8000-000000000001','21000000-0000-4000-8000-000000000002','NaN','QA bad')$q$,'Valor inválido');
select public.payroll_assign_approver('41000000-0000-4000-8000-000000000001','qa-finance@example.invalid','finance');
select public.payroll_assign_approver('41000000-0000-4000-8000-000000000001','qa-finance@example.invalid','authorized');
select public.payroll_assign_approver('41000000-0000-4000-8000-000000000001','qa-authorizer@example.invalid','authorized');
select pg_temp.expect_error($q$select public.payroll_assign_approver('41000000-0000-4000-8000-000000000001','qa-finance@example.invalid',null)$q$,'Perfil inválido');
select public.payroll_submit('61000000-0000-4000-8000-000000000001');
select pg_temp.expect_error($q$select public.payroll_simulate_payment('61000000-0000-4000-8000-000000000001')$q$,'Dupla aprovação obrigatória');
select pg_temp.expect_error($q$select public.payroll_approve('61000000-0000-4000-8000-000000000001')$q$,'Sem autorização financeira');
select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000002',true);
select pg_temp.expect_error($q$select public.credit_demo_entry('21000000-0000-4000-8000-000000000001','demo_credit',1,'QA foreign')$q$,'Conta não autorizada');
select pg_temp.expect_error($q$select public.payroll_assign_approver('41000000-0000-4000-8000-000000000001','qa-finance@example.invalid','finance')$q$,'Apenas responsável');
select public.payroll_approve('61000000-0000-4000-8000-000000000001');
select pg_temp.expect_error($q$select public.payroll_approve('61000000-0000-4000-8000-000000000001')$q$,'Aprovações exigem pessoas diferentes');
select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000003',true);
select public.payroll_approve('61000000-0000-4000-8000-000000000001');
select pg_temp.expect_error($q$select public.payroll_simulate_payment('61000000-0000-4000-8000-000000000001')$q$,'Sem acesso ao lote');
select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000001',true);
select public.payroll_simulate_payment('61000000-0000-4000-8000-000000000001');
select pg_temp.expect_error($q$select public.payroll_simulate_payment('61000000-0000-4000-8000-000000000001')$q$,'Lote já simulado');
do $$declare n integer;v numeric;begin
 select count(*) into n from public.payroll_payment_simulations where batch_id='61000000-0000-4000-8000-000000000001' and total_amount=100;
 if n<>1 then raise exception 'Payroll simulation count/amount wrong';end if;
 select balance into v from public.credit_account_balances() where account_id='21000000-0000-4000-8000-000000000001';if v<>75 then raise exception 'Legacy balance wrong';end if;
end $$;
reset role;
do $$declare f record;begin
 for f in select p.oid,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','credit_private') and p.proname in ('credit_demo_entry','credit_demo_transfer','payroll_approve','payroll_assign_approver','payroll_submit','payroll_simulate_payment') loop
 if has_function_privilege('anon',f.oid,'execute') then raise exception 'Anonymous execute on %',f.proname;end if;
 end loop;
 if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.prosecdef) then raise exception 'Public privileged functions remain';end if;
end $$;
rollback;
select 'PASS: 6 legacy RPCs guarded; own-account transfer; payroll submission, distinct approvers, simulation; duplicate/foreign/anonymous access denied; fixtures rolled back' as result;
