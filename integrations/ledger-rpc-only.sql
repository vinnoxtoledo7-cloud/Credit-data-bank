-- Applied to Supabase sandbox 2026-11-12.
-- The existing public.credit_demo_entry RPC calls a validated private SECURITY DEFINER
-- function that checks ownership, amount, account status, and overdraft on debit.
-- Direct client writes must be forbidden even if an RLS policy is later added.
revoke insert, update, delete, truncate, trigger, references
on public.credit_account_ledger from authenticated;
-- Client-facing RPC access remains available:
-- public.credit_demo_entry(uuid,text,numeric,text)
-- public.credit_demo_transfer(uuid,uuid,numeric,text)
-- IMPORTANT: legacy clients that directly INSERT ledger entries must migrate to RPC.
-- Future hardening: request-key idempotency, append-only audit, automated concurrency tests.
