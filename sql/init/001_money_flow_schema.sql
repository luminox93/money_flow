create extension if not exists pgcrypto;

create table if not exists asset_accounts (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  account_type text not null,
  institution text,
  currency_code text not null default 'KRW',
  opening_balance numeric(18,2) not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists transaction_sources (
  id uuid primary key default gen_random_uuid(),
  source_name text not null,
  source_type text not null,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists recurring_transactions (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  flow_type text not null check (flow_type in ('income', 'expense', 'transfer')),
  category text not null,
  amount numeric(18,2) not null,
  currency_code text not null default 'KRW',
  schedule_type text not null check (schedule_type in ('daily', 'weekly', 'monthly', 'yearly')),
  schedule_day integer,
  start_date date not null,
  end_date date,
  account_id uuid references asset_accounts(id),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists raw_transactions (
  id uuid primary key default gen_random_uuid(),
  source_id uuid not null references transaction_sources(id),
  external_id text,
  occurred_at timestamptz not null,
  merchant_name text,
  description text,
  amount numeric(18,2) not null,
  currency_code text not null default 'KRW',
  payment_method text,
  raw_payload jsonb not null,
  imported_at timestamptz not null default now(),
  unique (source_id, external_id)
);

create table if not exists normalized_transactions (
  id uuid primary key default gen_random_uuid(),
  raw_transaction_id uuid references raw_transactions(id) on delete set null,
  account_id uuid references asset_accounts(id),
  flow_type text not null check (flow_type in ('income', 'expense', 'transfer')),
  category text not null,
  subcategory text,
  title text not null,
  amount numeric(18,2) not null,
  currency_code text not null default 'KRW',
  occurred_on date not null,
  counterparty text,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_normalized_transactions_occurred_on
  on normalized_transactions (occurred_on);

create index if not exists idx_normalized_transactions_category
  on normalized_transactions (category);

create table if not exists account_balance_snapshots (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references asset_accounts(id) on delete cascade,
  snapshot_date date not null,
  balance numeric(18,2) not null,
  created_at timestamptz not null default now(),
  unique (account_id, snapshot_date)
);

create table if not exists daily_cashflow (
  flow_date date primary key,
  income_amount numeric(18,2) not null default 0,
  expense_amount numeric(18,2) not null default 0,
  transfer_amount numeric(18,2) not null default 0,
  net_amount numeric(18,2) not null default 0,
  closing_balance numeric(18,2),
  generated_at timestamptz not null default now()
);

create view if not exists vw_daily_transaction_summary as
select
  occurred_on as flow_date,
  sum(case when flow_type = 'income' then amount else 0 end) as income_amount,
  sum(case when flow_type = 'expense' then amount else 0 end) as expense_amount,
  sum(case when flow_type = 'transfer' then amount else 0 end) as transfer_amount,
  sum(case
    when flow_type = 'income' then amount
    when flow_type = 'expense' then -amount
    else 0
  end) as net_amount
from normalized_transactions
group by occurred_on;
