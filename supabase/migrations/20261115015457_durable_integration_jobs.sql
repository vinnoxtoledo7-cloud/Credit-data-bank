-- Private durable sandbox queue. No client grants, no ledger writes, no worker enabled.
create table baas_private.integration_jobs (
 id uuid primary key default gen_random_uuid(),
 provider text not null check(provider in ('mock','celcoin','asaas')),
 environment text not null default 'sandbox' check(environment='sandbox'),
 event_id text not null check(length(event_id) between 1 and 200),
 payload_sha256 text not null check(payload_sha256 ~ '^[a-f0-9]{64}$'),
 resource_reference text not null check(length(resource_reference) between 1 and 200),
 status text not null default 'pending' check(status in ('pending','processing','retry','processed','dead_letter')),
 attempts integer not null default 0 check(attempts between 0 and 5),
 available_at timestamptz not null default now(),
 lease_until timestamptz,
 lease_token uuid,
 verified_at timestamptz not null,
 created_at timestamptz not null default now(),
 processed_at timestamptz,
 last_error_code text check(last_error_code ~ '^[a-z0-9_]{1,80}$'),
 unique(provider,environment,event_id),
 check((status='processing')=(lease_until is not null and lease_token is not null))
);
alter table baas_private.integration_jobs enable row level security;
revoke all on baas_private.integration_jobs from public,anon,authenticated;
create index integration_jobs_ready on baas_private.integration_jobs(available_at,created_at) where status in ('pending','retry');
create index integration_jobs_expired on baas_private.integration_jobs(lease_until) where status='processing';
comment on table baas_private.integration_jobs is 'Verified sandbox event references only. Server worker not enabled. Never stores financial credentials or updates simulation balances.';

