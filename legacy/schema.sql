-- ============================================================
--  Project Ironveil — Supabase Database Schema
--  Run this in the Supabase SQL Editor (Dashboard > SQL Editor)
-- ============================================================


-- ─── EXTENSIONS ──────────────────────────────────────────────
-- (uuid-ossp is already enabled by default in Supabase)


-- ─── PROFILES ────────────────────────────────────────────────
-- One row per authenticated user (developer team member)
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text,
  role          text,
  is_public     boolean not null default false,
  avatar_url    text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.profiles is 'Developer team member profiles.';

-- Auto-create a profile row when a user signs up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ─── TASK STATES ─────────────────────────────────────────────
-- Stores the state of every task (keyed by task_id string)
create table if not exists public.task_states (
  task_id     text primary key,
  state       text not null default 'todo'
                check (state in ('todo','in-progress','done')),
  updated_at  timestamptz not null default now(),
  updated_by  uuid references public.profiles(id)
);

comment on table public.task_states is 'Current state of each task in the hardcoded task list.';


-- ─── TASK ASSIGNMENTS ────────────────────────────────────────
-- Assigns tasks to developers within a sprint
create table if not exists public.task_assignments (
  id             uuid primary key default gen_random_uuid(),
  task_id        text not null,
  assignee_id    uuid references public.profiles(id) on delete set null,
  sprint_active  boolean not null default false,
  created_at     timestamptz not null default now()
);

comment on table public.task_assignments is 'Sprint task assignments.';
create index on public.task_assignments(sprint_active);
create index on public.task_assignments(task_id);


-- ─── PUBLIC UPDATES ──────────────────────────────────────────
-- Developer changelog / devlog entries visible to everyone
create table if not exists public.public_updates (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  body        text not null,
  tag         text,                               -- e.g. MILESTONE, HOTFIX
  media_url   text,                               -- optional screenshot/video
  author_id   uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.public_updates is 'Public-facing development changelog entries.';
create index on public.public_updates(created_at desc);


-- ─── PLAYTEST STATUS ─────────────────────────────────────────
-- Single-row table controlling the public playtest badge
create table if not exists public.playtest_status (
  id          uuid primary key default gen_random_uuid(),
  status      text not null default 'closed'
                check (status in ('closed','soon','open')),
  platform    text,                               -- e.g. Meta Quest 2/3
  eta         text,                               -- free-text note shown publicly
  signup_url  text,                               -- optional external sign-up link
  updated_at  timestamptz not null default now()
);

comment on table public.playtest_status is 'Controls the public-facing playtest status badge.';

-- Seed a default row
insert into public.playtest_status (status) values ('closed')
on conflict do nothing;


-- ============================================================
--  ROW-LEVEL SECURITY (RLS)
-- ============================================================
-- Public tables: read allowed for anon, write requires auth.
-- Profiles: users can only write their own row.

-- ── profiles ──
alter table public.profiles enable row level security;

create policy "Public profiles are readable by everyone"
  on public.profiles for select
  using (true);

create policy "Users can insert their own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id);


-- ── task_states ──
alter table public.task_states enable row level security;

create policy "Anyone can read task states"
  on public.task_states for select
  using (true);

create policy "Authenticated users can upsert task states"
  on public.task_states for insert
  with check (auth.role() = 'authenticated');

create policy "Authenticated users can update task states"
  on public.task_states for update
  using (auth.role() = 'authenticated');


-- ── task_assignments ──
alter table public.task_assignments enable row level security;

create policy "Anyone can read task assignments"
  on public.task_assignments for select
  using (true);

create policy "Authenticated users can manage assignments"
  on public.task_assignments for all
  using (auth.role() = 'authenticated');


-- ── public_updates ──
alter table public.public_updates enable row level security;

create policy "Anyone can read updates"
  on public.public_updates for select
  using (true);

create policy "Authenticated users can insert updates"
  on public.public_updates for insert
  with check (auth.role() = 'authenticated');

create policy "Authors can update their updates"
  on public.public_updates for update
  using (auth.uid() = author_id);

create policy "Authors can delete their updates"
  on public.public_updates for delete
  using (auth.uid() = author_id);


-- ── playtest_status ──
alter table public.playtest_status enable row level security;

create policy "Anyone can read playtest status"
  on public.playtest_status for select
  using (true);

create policy "Authenticated users can manage playtest status"
  on public.playtest_status for all
  using (auth.role() = 'authenticated');


-- ============================================================
--  REALTIME
--  Enable realtime for all public-facing tables.
--  Run in Supabase Dashboard: Database > Replication > Tables
--  OR run this SQL (requires Supabase superuser):
-- ============================================================

-- alter publication supabase_realtime add table public.task_states;
-- alter publication supabase_realtime add table public.task_assignments;
-- alter publication supabase_realtime add table public.public_updates;
-- alter publication supabase_realtime add table public.profiles;
-- alter publication supabase_realtime add table public.playtest_status;

-- NOTE: Uncomment and run the above 5 lines to enable realtime.
-- Alternatively, go to Supabase Dashboard → Database → Replication
-- and toggle each table ON under the supabase_realtime publication.
