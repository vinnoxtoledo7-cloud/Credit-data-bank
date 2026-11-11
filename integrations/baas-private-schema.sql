-- Credit Data Bank BaaS sandbox schema (NOT APPLIED).
-- Private schema: never expose through Supabase Data API.
create schema if not exists baas_private;
revoke all on schema baas_private from public, anon, authenticated;
create table if not exists baas_private.account_applications (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id),
 customer_profile_id uuid not null references public.customer_profiles(id),
 account_type text not null check (account_type in ('PF','PJ')),
 provider text,
 provider_reference text,
 status text not null default 'draft' check (status in ('draft','submitted','under_review','more_info_required','approved','rejected')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique (customer_profile_id)
);
create table if not exists baas_private.transfer_intents (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id),
 provider text,
 provider_reference text,
 idempotency_key text not null unique,
 amount_cents bigint not null check (amount_cents > 0),
 method text not null check (method in ('pix','internal','ted')),
 status text not null default 'pending' check (status in ('pending','processing','completed','failed','reversed')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create unique index if not exists transfer_provider_reference_unique on baas_private.transfer_intents(provider,provider_reference) where provider_reference is not null;
create table if not exists baas_private.webhook_inbox (
 id uuid primary key default gen_random_uuid(),
 provider text not null,
 provider_event_id text not null,
 payload_sha256 text not null check (payload_sha256 ~ '^[a-f0-9]{64}$'),
 verified_at timestamptz not null,
 received_at timestamptz not null default now(),
 processed_at timestamptz,
 processing_status text not null default 'pending' check (processing_status in ('pending','processed','failed')),
 unique (provider,provider_event_id)
);
create table if not exists baas_private.audit_events (
 id bigint generated always as identity primary key,
 actor_user_id uuid references auth.users(id),
 action text not null,
 entity_type text not null,
 entity_id text not null,
 metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
alter table baas_private.account_applications enable row level security;
alter table baas_private.transfer_intents enable row level security;
alter table baas_private.webhook_inbox enable row level security;
alter table baas_private.audit_events enable row level security;
-- No client policies. Server-only access with explicitly reviewed privileges.
revoke all on all tables in schema baas_private from public, anon, authenticated;
-- Audit records are append-only at the database role level; privileged operations
-- and retention policies still require independent controls and review.
