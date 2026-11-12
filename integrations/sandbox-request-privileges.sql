-- Applied to Supabase sandbox 2026-11-12.
-- RLS controls row ownership; SQL grants enforce the least-privilege operation set.
revoke all on table public.sandbox_account_requests from anon, authenticated;
grant select, insert on table public.sandbox_account_requests to authenticated;
-- No UPDATE, DELETE, TRUNCATE, TRIGGER or REFERENCES for client roles.
