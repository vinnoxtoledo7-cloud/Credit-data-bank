-- Applied to Supabase sandbox on 2026-11-11.
-- Log account application creation and updates; no personal documents in metadata.
create or replace function baas_private.audit_application_change()
returns trigger language plpgsql set search_path = '' as $$
begin
 insert into baas_private.audit_events(actor_user_id,action,entity_type,entity_id,metadata)
 values(new.owner_id,
  case when tg_op='INSERT' then 'application_created' else 'application_updated' end,
  'account_application',new.id::text,
  jsonb_build_object('status',new.status,'account_type',new.account_type));
 return new;
end $$;
drop trigger if exists trg_audit_application on baas_private.account_applications;
create trigger trg_audit_application after insert or update
on baas_private.account_applications for each row
execute function baas_private.audit_application_change();
revoke all on function baas_private.audit_application_change() from public,anon,authenticated;
