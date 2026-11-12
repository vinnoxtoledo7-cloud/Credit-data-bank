-- Applied in sandbox 2026-11-12. Preserve legacy simulated ledger insertion pending RPC migration.
revoke update, delete, truncate, trigger, references
on public.credit_account_ledger, public.credit_demo_transfers, public.credit_accounts
from authenticated;
revoke insert on public.credit_demo_transfers from authenticated;
-- IMPORTANT: credit_account_ledger INSERT remains granted for compatibility with existing
-- simulated credit flows. Migrate to a validated server-side RPC before revoking it.
-- Private SECURITY DEFINER transfer functions remain responsible for atomic transfer writes.
