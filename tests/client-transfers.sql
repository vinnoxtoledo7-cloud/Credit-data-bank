begin;
-- Fixtures exist only within this transaction; ROLLBACK preserves all existing data.
insert into auth.users(id) values ('10000000-0000-4000-8000-000000000001'),('10000000-0000-4000-8000-000000000002'),('10000000-0000-4000-8000-000000000003');
insert into public.credit_accounts(id,owner_id,account_type,display_name) values
('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','PF','TEST Sender'),
('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','PJ','TEST Receiver');
insert into public.credit_account_ledger(account_id,amount,description,entry_type) values('20000000-0000-4000-8000-000000000001',100,'TEST seed','demo_credit');
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
do $$
declare b uuid; r jsonb; t uuid; n integer; v numeric;
begin
 r:=public.credit_beneficiary_save('20000000-0000-4000-8000-000000000001','Self');
 if not r ? 'error' then raise exception 'Own account accepted'; end if;
 r:=public.credit_beneficiary_save('20000000-0000-4000-8000-000000000002','Receiver'); b:=(r->>'id')::uuid;
 if b is null then raise exception 'Beneficiary failed %',r; end if;
 r:=public.credit_beneficiary_save('20000000-0000-4000-8000-000000000002','Updated alias');
 if (r->>'id')::uuid<>b then raise exception 'Duplicate beneficiary'; end if;
 r:=public.credit_client_transfer('20000000-0000-4000-8000-000000000001',b,25.50,'TEST transfer','30000000-0000-4000-8000-000000000001');
 t:=(r->>'id')::uuid; if t is null then raise exception 'Transfer failed %',r; end if;
 r:=public.credit_client_transfer('20000000-0000-4000-8000-000000000001',b,25.50,'TEST transfer','30000000-0000-4000-8000-000000000001');
 if (r->>'id')::uuid<>t or not (r->>'replayed')::boolean then raise exception 'Idempotency failed'; end if;
 r:=public.credit_client_transfer('20000000-0000-4000-8000-000000000001',b,26,'TEST transfer','30000000-0000-4000-8000-000000000001');
 if not r ? 'error' then raise exception 'Changed replay accepted'; end if;
 foreach v in array array[-1,0,0.001,1000001,75,'NaN'::numeric,'Infinity'::numeric] loop
 r:=public.credit_client_transfer('20000000-0000-4000-8000-000000000001',b,v,'TEST invalid',gen_random_uuid());
 if not r ? 'error' then raise exception 'Invalid amount accepted %',v; end if;
 end loop;
 r:=public.credit_client_transfer('20000000-0000-4000-8000-000000000002',b,1,'TEST IDOR',gen_random_uuid());
 if not r ? 'error' then raise exception 'Foreign source accepted'; end if;
 select balance into v from public.credit_account_balances() where account_id='20000000-0000-4000-8000-000000000001';
 if v<>74.50 then raise exception 'Incorrect sender balance %',v; end if;
 begin
 update public.credit_client_transfers set amount=1 where id=t;
 raise exception 'Transfer mutable';
 exception when insufficient_privilege then null; end;
 begin
 insert into public.credit_audit_events(actor_id,action,outcome) values(auth.uid(),'forged','success');
 raise exception 'Audit forgeable';
 exception when insufficient_privilege then null; end;
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
 select count(*) into n from public.credit_client_transfers where id=t;if n<>1 then raise exception 'Recipient receipt missing'; end if;
 select balance into v from public.credit_account_balances() where account_id='20000000-0000-4000-8000-000000000002';if v<>25.50 then raise exception 'Receiver balance wrong';end if;
 select count(*) into n from public.credit_beneficiaries where id=b;if n<>0 then raise exception 'Beneficiary leaked';end if;
 r:=public.credit_beneficiary_remove(b);if not r ? 'error' then raise exception 'Foreign delete allowed';end if;
 r:=public.credit_client_transfer('20000000-0000-4000-8000-000000000002',b,1,'TEST foreign beneficiary',gen_random_uuid());if not r ? 'error' then raise exception 'Foreign beneficiary allowed';end if;
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',true);
 select count(*) into n from public.credit_client_transfers where id=t;if n<>0 then raise exception 'Receipt leaked';end if;
 select count(*) into n from public.credit_account_ledger where client_transfer_id=t;if n<>0 then raise exception 'Ledger leaked';end if;
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
 for n in 1..21 loop r:=public.credit_client_transfer('20000000-0000-4000-8000-000000000001',b,1,'TEST rate',gen_random_uuid()); end loop;
 if r->>'error'<>'Limite de tentativas por minuto atingido' then raise exception 'Rate limit failed %',r;end if;
 r:=public.credit_beneficiary_remove(b);if r ? 'error' then raise exception 'Remove failed';end if;
 select count(*) into n from public.credit_client_transfers where id=t;if n<>1 then raise exception 'Removal lost history';end if;
end $$;
reset role;
do $$declare n integer;begin
 select count(*) into n from (select t.id,count(l.id) c,sum(l.amount) s from public.credit_client_transfers t join public.credit_account_ledger l on l.client_transfer_id=t.id where t.sender_id='10000000-0000-4000-8000-000000000001' group by t.id having count(l.id)<>2 or sum(l.amount)<>0) q;
 if n<>0 then raise exception 'Double-entry invariant failed';end if;
end $$;
set local role anon;
do $$begin
 begin perform public.credit_client_transfer(null,null,1,'TEST',gen_random_uuid());raise exception 'Anonymous RPC accepted';exception when insufficient_privilege then null;end;
 begin perform * from public.credit_client_transfers;raise exception 'Anonymous table access';exception when insufficient_privilege then null;end;
end $$;
reset role;
rollback;
select 'PASS: transactional transfer, idempotency, validation, balances, RLS, immutability, audit, limits, anonymous access; fixtures rolled back' as result;
