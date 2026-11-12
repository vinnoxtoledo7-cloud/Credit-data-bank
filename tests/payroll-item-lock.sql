begin;
insert into auth.users(id,email) values('98000000-0000-4000-8000-000000000001','item-qa@example.invalid');
insert into public.payroll_companies(id,owner_id,name) values('98000000-0000-4000-8000-000000000002','98000000-0000-4000-8000-000000000001','QA item lock');
insert into public.payroll_employees(id,company_id,full_name) values('98000000-0000-4000-8000-000000000003','98000000-0000-4000-8000-000000000002','QA employee'),('98000000-0000-4000-8000-000000000005','98000000-0000-4000-8000-000000000002','QA second employee');
insert into public.payroll_batches(id,company_id,competence,created_by) values('98000000-0000-4000-8000-000000000004','98000000-0000-4000-8000-000000000002','2026-11','98000000-0000-4000-8000-000000000001');
set local role authenticated;
select set_config('request.jwt.claim.sub','98000000-0000-4000-8000-000000000001',true);
insert into public.payroll_batch_items(batch_id,employee_id,net_amount) values('98000000-0000-4000-8000-000000000004','98000000-0000-4000-8000-000000000003',10);
select public.payroll_submit('98000000-0000-4000-8000-000000000004');
do $$ declare rejected boolean:=false;begin
 begin insert into public.payroll_batch_items(batch_id,employee_id,net_amount) values('98000000-0000-4000-8000-000000000004','98000000-0000-4000-8000-000000000005',20);exception when raise_exception then if sqlerrm<>'Folha bloqueada após envio' then raise;end if;rejected:=true;end;
 if not rejected then raise exception 'Item inserted after submit';end if;
 if (select sum(net_amount) from public.payroll_batch_items where batch_id='98000000-0000-4000-8000-000000000004')<>10 then raise exception 'Unexpected total';end if;
end $$;
rollback;
select 'PASS: authenticated creator inserts draft item without UPDATE privilege on batch; submitted batch refuses mutation; fixtures rolled back' result;
