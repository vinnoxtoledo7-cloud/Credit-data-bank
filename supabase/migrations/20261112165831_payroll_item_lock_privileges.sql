-- Trigger-only private implementation: outer table RLS still authorizes the DML.
create or replace function credit_private.payroll_block_item_changes() returns trigger language plpgsql security definer set search_path='' as $$
declare b uuid; s text;
begin
 if tg_op='UPDATE' and (old.batch_id<>new.batch_id or old.employee_id<>new.employee_id) then raise exception 'Vínculo do lançamento imutável'; end if;
 b:=case when tg_op='DELETE' then old.batch_id else new.batch_id end;
 select status into s from public.payroll_batches where id=b for update;
 if s is distinct from 'draft' then raise exception 'Folha bloqueada após envio'; end if;
 return case when tg_op='DELETE' then old else new end;
end $$;
revoke all on function credit_private.payroll_block_item_changes() from public,anon,authenticated;
create or replace trigger payroll_items_immutable before insert or update or delete on public.payroll_batch_items for each row execute function credit_private.payroll_block_item_changes();

