-- NOT EXECUTED: connector confirmation expired. Disposable QA identities only.
begin;
create temp table qa_cleanup_ids as select id from auth.users where id in ('681c2403-6d6e-4277-96e4-1f1ff3698586','e16e83de-e93b-4f14-a4c5-de6fe3748cef','f7539e4e-3814-4420-843d-458ffd71ad58') and raw_user_meta_data->>'qa'='readiness-20261112';
delete from auth.sessions where user_id in(select id from qa_cleanup_ids);
delete from credit_private.demo_entry_requests where owner_id in(select id from qa_cleanup_ids);
delete from public.credit_account_ledger where account_id in(select id from public.credit_accounts where owner_id in(select id from qa_cleanup_ids));
delete from public.credit_demo_transfers where owner_id in(select id from qa_cleanup_ids);
delete from public.credit_client_transfers where sender_id in(select id from qa_cleanup_ids) and recipient_id in(select id from qa_cleanup_ids);
delete from public.credit_beneficiaries where owner_id in(select id from qa_cleanup_ids);
delete from public.credit_audit_events where actor_id in(select id from qa_cleanup_ids);
delete from public.credit_accounts where owner_id in(select id from qa_cleanup_ids);
delete from auth.users where id in(select id from qa_cleanup_ids);
commit;

