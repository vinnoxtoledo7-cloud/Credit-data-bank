-- Applied to Supabase sandbox on 2026-11-11. Preserve ownership integrity.
create or replace function baas_private.enforce_application_owner()
returns trigger language plpgsql set search_path = '' as $$
begin
 if not exists (
  select 1 from public.customer_profiles p
  where p.id = new.customer_profile_id
    and p.owner_id = new.owner_id
    and p.account_type = new.account_type
 ) then
  raise exception 'application profile ownership mismatch' using errcode = '23514';
 end if;
 return new;
end $$;
drop trigger if exists trg_application_owner on baas_private.account_applications;
create trigger trg_application_owner
before insert or update of owner_id, customer_profile_id, account_type
on baas_private.account_applications
for each row execute function baas_private.enforce_application_owner();
revoke all on function baas_private.enforce_application_owner() from public, anon, authenticated;
