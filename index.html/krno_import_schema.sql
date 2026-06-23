-- ============================================================
-- KRNO IMP — نظام المستندات الاستيرادية
-- Schema setup for shared Supabase project (multi-schema approach)
-- Run this once in: Supabase Dashboard > SQL Editor > New query
-- ============================================================

-- 1) Dedicated schema so this doesn't clash with your warehouse /
--    salary / other apps living in the same Supabase project.
create schema if not exists krno_import;

-- Allow the API (PostgREST) to see this schema.
-- IMPORTANT: after running this script, go to
-- Project Settings > API > "Exposed schemas" and add: krno_import
-- (public is exposed by default, krno_import is not, until you add it there)

-- ============================================================
-- TABLES
-- ============================================================

create table if not exists krno_import.invoices (
  id            bigint generated always as identity primary key,
  file_no       text not null unique,
  factory       text not null check (factory in ('krno','lotus')),
  invoice_no    text not null,
  supplier      text not null,
  origin        text,
  item_name     text,
  quantity      numeric,
  unit          text default 'طن',
  price_per_ton numeric,
  amount        numeric not null,
  currency      text not null check (currency in ('USD','EUR','EGP')),
  bank          text,
  status        text not null default 'قيد المعالجة',
  pay_method_type   text check (pay_method_type in ('bank_transfer','foreign_transfer','cash')),
  pay_percent       numeric,
  pay_amount_set    numeric,
  foreign_bank_name text,
  invoice_date  date,
  shipping_company text,
  eta           date,
  description   text,
  notes         text,
  created_by    text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table if not exists krno_import.payments (
  id            bigint generated always as identity primary key,
  invoice_id    bigint not null references krno_import.invoices(id) on delete cascade,
  amount        numeric not null,
  currency      text not null check (currency in ('USD','EUR','EGP')),
  bank          text,
  method_type   text check (method_type in ('bank_transfer','foreign_transfer','cash')),
  ref           text,
  payment_date  date not null default current_date,
  notes         text,
  created_by    text,
  created_at    timestamptz not null default now()
);

create table if not exists krno_import.costs (
  id            bigint generated always as identity primary key,
  invoice_id    bigint not null references krno_import.invoices(id) on delete cascade,
  cost_type     text not null,
  amount        numeric not null,
  currency      text not null check (currency in ('USD','EUR','EGP')),
  cost_date     date not null default current_date,
  notes         text,
  created_by    text,
  created_at    timestamptz not null default now()
);

create table if not exists krno_import.cost_types (
  id        bigint generated always as identity primary key,
  name      text not null unique,
  created_at timestamptz not null default now()
);

create table if not exists krno_import.app_users (
  id        bigint generated always as identity primary key,
  username  text not null unique,
  password  text not null,
  name      text not null,
  role      text not null check (role in ('admin','manager','viewer')),
  avatar    text,
  created_at timestamptz not null default now()
);

-- ============================================================
-- SEED DATA (default cost types + demo users — change passwords later)
-- ============================================================

insert into krno_import.cost_types (name) values
  ('مدفوعة إلكترونية'), ('نقل'), ('مصاريف تخليص جمركي'), ('غرامات'),
  ('مصاريف أرضيات'), ('عمولات بنكية'), ('عمولة تحويل بنكي'), ('مصاريف شحن')
on conflict (name) do nothing;

insert into krno_import.app_users (username, password, name, role, avatar) values
  ('admin',  'admin123', 'المدير العام',  'admin',   'AD'),
  ('khaled', 'khaled1',  'خالد',          'manager', 'KH'),
  ('viewer', 'view1',    'مستخدم مشاهدة','viewer',  'VW')
on conflict (username) do nothing;

-- ============================================================
-- updated_at trigger for invoices
-- ============================================================
create or replace function krno_import.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_invoices_updated_at on krno_import.invoices;
create trigger trg_invoices_updated_at
  before update on krno_import.invoices
  for each row execute function krno_import.set_updated_at();

-- ============================================================
-- ROW LEVEL SECURITY
-- Simplified: anon key can read/write everything (app handles its
-- own login screen). This matches a small-team internal tool — not
-- exposed publicly. Tighten later if you add Supabase Auth.
-- ============================================================
alter table krno_import.invoices   enable row level security;
alter table krno_import.payments   enable row level security;
alter table krno_import.costs      enable row level security;
alter table krno_import.cost_types enable row level security;
alter table krno_import.app_users  enable row level security;

drop policy if exists allow_all_invoices   on krno_import.invoices;
drop policy if exists allow_all_payments   on krno_import.payments;
drop policy if exists allow_all_costs      on krno_import.costs;
drop policy if exists allow_all_cost_types on krno_import.cost_types;
drop policy if exists allow_all_app_users  on krno_import.app_users;

create policy allow_all_invoices   on krno_import.invoices   for all using (true) with check (true);
create policy allow_all_payments   on krno_import.payments   for all using (true) with check (true);
create policy allow_all_costs      on krno_import.costs      for all using (true) with check (true);
create policy allow_all_cost_types on krno_import.cost_types for all using (true) with check (true);
create policy allow_all_app_users  on krno_import.app_users  for select using (true);
-- app_users: only allow reading (for login check) — no public insert/update/delete via API.

-- ============================================================
-- REALTIME
-- Enable realtime broadcasting for live updates across devices.
-- ============================================================
alter publication supabase_realtime add table krno_import.invoices;
alter publication supabase_realtime add table krno_import.payments;
alter publication supabase_realtime add table krno_import.costs;
alter publication supabase_realtime add table krno_import.cost_types;

-- ============================================================
-- DONE.
-- Next steps:
-- 1. Project Settings > API > Exposed schemas > add "krno_import"
-- 2. Copy your Project URL + anon public key into the app
-- 3. (Optional) Change default passwords in krno_import.app_users
-- ============================================================
