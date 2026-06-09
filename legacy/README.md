# Project Ironveil — Setup Guide

## Files
| File | Purpose |
|------|---------|
| `index.html` | Public portal — no login required |
| `admin.html` | Developer dashboard — requires Supabase auth |
| `schema.sql` | Full Supabase database schema + RLS policies |

---

## 1. Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) and create a new project.
2. Note your **Project URL** and **anon/public API key** from  
   **Settings → API**.

---

## 2. Run the Schema

1. In the Supabase dashboard, go to **SQL Editor**.
2. Paste the contents of `schema.sql` and click **Run**.
3. At the bottom of the schema file, uncomment and run the 5  
   `alter publication` lines **or** go to  
   **Database → Replication** and toggle on all 5 tables.

---

## 3. Add Your Credentials

In both `index.html` and `admin.html`, replace:

```js
const SUPABASE_URL = 'https://YOUR_PROJECT.supabase.co';
const SUPABASE_KEY = 'YOUR_PUBLIC_ANON_KEY';
```

with your real values from **Settings → API**.

---

## 4. Create Developer Accounts

In the Supabase dashboard:

1. Go to **Authentication → Users → Invite User**.
2. Send invite emails to each team member.
3. Once they sign in via `admin.html`, a `profiles` row is  
   auto-created. They can then fill in their display name and role.

---

## 5. Host the Files

These are plain HTML files — host them anywhere:

- **Netlify / Vercel**: drag-and-drop the folder.
- **GitHub Pages**: commit to a repo and enable Pages.
- **Supabase Storage**: upload as a static site bucket.

Make sure `index.html` and `admin.html` are in the **same directory**  
so the `Developer Login` button link (`admin.html`) works correctly.

---

## Architecture Overview

```
Public Portal (index.html)
  ├── Reads: task_states, task_assignments, profiles, public_updates, playtest_status
  ├── Auth: none (anon key only)
  └── Realtime: subscribes to all 5 tables → live updates

Developer Dashboard (admin.html)
  ├── Auth: Supabase email/password
  ├── Pages: Overview · Roadmap · Sprint · Updates · Team · Playtest
  ├── Writes: all 5 tables
  └── Realtime: subscribes → reflects other devs' changes live
```

### Database Tables

| Table | Description |
|-------|-------------|
| `profiles` | One row per developer; controls public team visibility |
| `task_states` | State (`todo` / `in-progress` / `done`) for each task ID |
| `task_assignments` | Sprint task → assignee mappings |
| `public_updates` | Devlog/changelog entries posted to public portal |
| `playtest_status` | Single-row; controls public playtest badge |

### Task List

Tasks are defined as a hardcoded `TASKS` array in **both** HTML files.  
They share the same `id` values — keep both in sync when adding tasks.  
The `task_states` table stores state by `task_id` (text primary key).

---

## Adding Tasks

1. Add a new entry to the `TASKS` array in `index.html`.
2. Add the same entry to the `TASKS` array in `admin.html`.
3. No database migration needed — new tasks appear as `planned` automatically.

---

## RLS Summary

All tables are readable by everyone (including anonymous visitors).  
Write access requires a signed-in user (`auth.role() = 'authenticated'`).  
Users can only modify their own `profiles` row.
