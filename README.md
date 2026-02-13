# 📅 Family Schedule App - Setup Guide

A full-featured family scheduling app built with **Next.js**, **Supabase**, and **Telegram Bot** integration. Features a Google Calendar-style UI (RTL/Hebrew), AI-powered natural language event creation, voice message support, Telegram notifications, daily schedule summaries, and automated reminders.

---

## 📋 Table of Contents

1. [Features](#-features)
2. [Tech Stack](#-tech-stack)
3. [Prerequisites](#-prerequisites)
4. [Project Structure](#-project-structure)
5. [Step 1: Supabase Setup](#step-1-supabase-setup)
6. [Step 2: Create Database Tables](#step-2-create-database-tables)
7. [Step 3: Telegram Bot Setup](#step-3-telegram-bot-setup)
8. [Step 4: OpenAI API Key](#step-4-openai-api-key)
9. [Step 5: Environment Variables](#step-5-environment-variables)
10. [Step 6: Customize Family Members](#step-6-customize-family-members)
11. [Step 7: Deploy & Set Up Cron Jobs](#step-7-deploy--set-up-cron-jobs)
12. [Step 8: Set Up Telegram Webhook](#step-8-set-up-telegram-webhook)
13. [API Endpoints](#-api-endpoints)
14. [Cron Jobs (Optional)](#-cron-jobs-optional)
15. [Troubleshooting](#-troubleshooting)

---

## ✨ Features

- **Google Calendar-style UI** — Day, week, and month views with drag-and-drop
- **RTL/Hebrew support** — Fully right-to-left interface
- **AI event parsing** — Type "{{PERSON_1}} basketball Monday 19:00" and it auto-fills the form
- **Voice messages** — Send a voice note to the Telegram bot to add events
- **Telegram bot** — Add events, check today/tomorrow/weekly schedule via chat commands
- **Telegram notifications** — Get notified when new events are added
- **Automated reminders** — Get a Telegram reminder X minutes before an event
- **Daily schedule** — Automatic morning summary of today's events via Telegram
- **Announcements board** — Pin family-wide announcements
- **Conflict detection** — Visual warning when events overlap for the same person
- **Person filtering** — Toggle which family members' events to show
- **Custom categories** — Add your own event categories
- **Multi-day events** — Support for events spanning multiple days
- **Mobile responsive** — Optimized mobile layout with bottom navigation

---

## 🛠 Tech Stack

| Component | Technology |
|-----------|-----------|
| Frontend | Next.js (App Router), React, Tailwind CSS |
| Backend | Next.js API Routes |
| Database | Supabase (PostgreSQL) |
| AI | OpenAI GPT-4o-mini (event parsing) + Whisper (voice) |
| Notifications | Telegram Bot API |
| Cron Jobs | Supabase pg_cron + pg_net (optional) |

---

## 📦 Prerequisites

- Node.js 18+
- A [Supabase](https://supabase.com) account (free tier works, Pro for cron jobs)
- A [Telegram](https://telegram.org) account
- An [OpenAI](https://platform.openai.com) API key (for AI features)

---

## 📁 Project Structure

All source files are provided in the `src/` folder, ready to copy into your Next.js project. **No hardcoded personal info** — everything is driven by environment variables.

```
src/
├── app/
│   ├── family-schedule/
│   │   ├── page.tsx                    # Page entry point
│   │   ├── layout.tsx                  # Layout wrapper
│   │   └── FamilyScheduleClient.tsx    # Main client component
│   └── api/family/
│       ├── events/
│       │   ├── route.ts                # GET (list) + POST (create) events
│       │   └── [id]/route.ts           # PUT (update) + DELETE events
│       ├── announcements/
│       │   ├── route.ts                # GET + POST announcements
│       │   └── [id]/route.ts           # DELETE announcements
│       ├── parse-event/route.ts        # AI natural language → event parser
│       ├── check-reminders/route.ts    # Cron: check & send due reminders
│       ├── daily-schedule/route.ts     # Cron: send morning schedule summary
│       └── telegram-webhook/route.ts   # Telegram bot webhook handler
└── lib/
    ├── telegram-family.ts              # Telegram bot utilities (send, notify, etc.)
    └── supabase/
        └── admin.ts                    # Supabase admin client factory

migrations/
├── 001_create_family_events.sql
├── 002_create_family_announcements.sql
├── 003_create_cron_reminders.sql       # Optional (pg_cron)
└── 004_create_cron_daily_schedule.sql  # Optional (pg_cron)

.env.example                            # All required environment variables
```

### How Personalization Works

Family members, emojis, default person, and categories are all read from environment variables:

| ENV Variable | Where Used | Example |
|---|---|---|
| `NEXT_PUBLIC_FAMILY_MEMBERS` | Client UI (people list, filter, modal) | `אבא,אמא,ילד1,ילד2` |
| `NEXT_PUBLIC_DEFAULT_PERSON` | Client UI (default in "new event" form) | `אבא` |
| `NEXT_PUBLIC_FAMILY_CATEGORIES` | Client UI (optional category override) | `אימון,חוג,עבודה,משפחה,אחר` |
| `FAMILY_MEMBERS` | Server-side (Telegram, AI prompts) | `אבא,אמא,ילד1,ילד2` |
| `FAMILY_MEMBER_EMOJIS` | Server-side (Telegram message formatting) | `👨,👩,👧,👦` |
| `DEFAULT_PERSON` | Server-side (AI default when no name given) | `אבא` |
| `TELEGRAM_BOT_USERNAME` | Server-side (Telegram command routing) | `my_family_bot` |

Person colors in the calendar UI are auto-assigned from a palette — no config needed.

---

## Step 1: Supabase Setup

1. Go to [supabase.com](https://supabase.com) and create a new project
2. Choose a region close to your users (e.g., `eu-central-1` for Israel)
3. Set a strong database password (save it somewhere safe)
4. Wait for the project to initialize (~2 minutes)
5. Go to **Project Settings → API** and copy:
   - **Project URL** → this becomes `NEXT_PUBLIC_SUPABASE_URL`
   - **service_role key** (under "Project API keys") → this becomes `SUPABASE_SERVICE_ROLE_KEY`

> ⚠️ **Never expose** the `service_role` key in client-side code. It's only used in API routes (server-side).

---

## Step 2: Create Database Tables

Go to **Supabase Dashboard → SQL Editor** and run the following migrations **in order**:

### Migration 1: Events Table

```sql
-- Family Schedule - Events Table
create table if not exists family_events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  person text not null,
  category text not null,
  start_time timestamptz not null,
  end_time timestamptz not null,
  recurring boolean default false,
  reminder_minutes int,
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Index for date range queries
create index if not exists idx_family_events_start_time on family_events (start_time);
create index if not exists idx_family_events_person on family_events (person);
```

### Migration 2: Announcements Table

```sql
-- Family Schedule - Announcements Board
create table if not exists family_announcements (
  id uuid primary key default gen_random_uuid(),
  text text not null,
  color int default 0,
  created_at timestamptz default now()
);
```

> 💡 SQL files are also available in the `migrations/` folder of this guide.

### Required Supabase Features

| Feature | Required? | Plan |
|---------|-----------|------|
| PostgreSQL database | ✅ Yes | Free |
| REST API (PostgREST) | ✅ Yes | Free |
| `pg_cron` extension | ❌ Optional | Pro+ |
| `pg_net` extension | ❌ Optional | Pro+ |

If your plan doesn't support `pg_cron`/`pg_net`, set `DISABLE_CRON_JOBS=true` in your `.env`. The app will work fine without automated reminders and daily schedule—you can trigger them manually via the API endpoints.

---

## Step 3: Telegram Bot Setup

### 3.1 Create the Bot

1. Open Telegram and search for **@BotFather**
2. Send `/newbot`
3. Choose a **display name** (e.g., "Family Schedule Bot")
4. Choose a **username** (must end in `bot`, e.g., `my_family_schedule_bot`)
5. BotFather will give you a **token** like `123456789:ABCdefGhIjKlMnOpQrStUvWxYz`
6. **Save this token** → this becomes `TELEGRAM_CHAT_BOT_FAMILY`
7. **Save the username** (without @) → this becomes `TELEGRAM_BOT_USERNAME`

### 3.2 Set Bot Commands (Optional)

Send this to @BotFather:
```
/setcommands
```
Then select your bot and paste:
```
today - לוז היום
tomorrow - לוז מחר
week - לוז שבועי
site - לינק ליומן באתר
help - עזרה
```

### 3.3 Get Chat IDs

You need the chat ID of each person/group that should receive notifications.

**For a personal chat:**
1. Send any message to your bot
2. Open: `https://api.telegram.org/bot{{YOUR_BOT_TOKEN}}/getUpdates`
3. Look for `"chat":{"id": 123456789}` — that's your chat ID

**For a group chat:**
1. Add the bot to the group
2. Send a message in the group
3. Check `getUpdates` as above — group IDs are negative numbers (e.g., `-100123456789`)

**Alternative:** Search for `@userinfobot` or `@RawDataBot` on Telegram and message them to get your chat ID.

4. Collect all chat IDs, separate with commas → `TELEGRAM_CHAT_ID_FAMILY`

### 3.4 Enable Group Privacy (for group bots)

If using in a group, tell @BotFather:
```
/setprivacy
```
Select your bot → **Disable** (so it can read all messages, not just `/commands`)

---

## Step 4: OpenAI API Key

1. Go to [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
2. Create a new API key
3. Save it → this becomes `OPENAI_API_KEY`

> The app uses `gpt-4o-mini` for event parsing and `whisper-1` for voice transcription. Both are very cost-efficient (~$0.01 per request).

---

## Step 5: Environment Variables

Copy `.env.example` to `.env.local` in your project root:

```bash
cp family-schedule-guide/.env.example .env.local
```

Fill in all values. See `.env.example` for the full list with descriptions.

Key variables:

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://your-project-id.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# OpenAI
OPENAI_API_KEY=sk-your-openai-key

# Telegram
TELEGRAM_CHAT_BOT_FAMILY=your-bot-token
TELEGRAM_BOT_USERNAME=my_family_bot
TELEGRAM_CHAT_ID_FAMILY=-100111111111,-100222222222

# Family Members (this is all you need to personalize the app!)
FAMILY_MEMBERS=אבא,אמא,ילד1,ילד2,ילד3
FAMILY_MEMBER_EMOJIS=👨,👩,👧,👦,👶
DEFAULT_PERSON=אבא
NEXT_PUBLIC_FAMILY_MEMBERS=אבא,אמא,ילד1,ילד2,ילד3
NEXT_PUBLIC_DEFAULT_PERSON=אבא

# Cron
CRON_SECRET=any-random-secret-string
DISABLE_CRON_JOBS=false
NEXT_PUBLIC_APP_URL=https://your-domain.com
```

---

## Step 6: Copy Source Files

Copy the `src/` folder contents into your Next.js project:

```bash
# Copy all source files
cp -r family-schedule-guide/src/app/* app/
cp -r family-schedule-guide/src/lib/* lib/
```

**No code editing needed!** All personalization (family members, emojis, bot username, URLs) is driven by environment variables. Just set them in `.env.local` and the app adapts automatically.

---

## Step 7: Deploy to Vercel

### 7.1 Push to Git

```bash
git init
git add .
git commit -m "Initial commit - family schedule app"
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

### 7.2 Connect Vercel to Git

1. Go to [vercel.com](https://vercel.com) and click **Add New Project**
2. Import your GitHub repository
3. Vercel auto-detects Next.js — keep default settings
4. Before deploying, add **Environment Variables** in the Vercel project settings:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `OPENAI_API_KEY`
   - `TELEGRAM_CHAT_BOT_FAMILY`
   - `TELEGRAM_BOT_USERNAME`
   - `TELEGRAM_CHAT_ID_FAMILY`
   - `FAMILY_MEMBERS`
   - `FAMILY_MEMBER_EMOJIS`
   - `DEFAULT_PERSON`
   - `NEXT_PUBLIC_FAMILY_MEMBERS`
   - `NEXT_PUBLIC_DEFAULT_PERSON`
   - `NEXT_PUBLIC_APP_URL`
   - `CRON_SECRET`
   - `DISABLE_CRON_JOBS`
5. Click **Deploy**

Every push to `main` will auto-deploy.

### 7.3 Set Up Cron Jobs (Optional — requires Supabase Pro)

After deploying, if your Supabase plan supports `pg_cron` and `pg_net`:

1. Go to **Supabase Dashboard → SQL Editor**
2. Run `migrations/003_create_cron_reminders.sql` — replace `{{YOUR_APP_URL}}` with your Vercel URL
3. Run `migrations/004_create_cron_daily_schedule.sql` — replace `{{YOUR_APP_URL}}` with your Vercel URL

| Job | Schedule | Purpose |
|-----|----------|---------|
| `family-schedule-reminders` | Every 5 minutes | Checks for due reminders and sends Telegram notifications |
| `family-daily-schedule` | 4:00 AM UTC (7:00 AM Israel) | Sends daily event summary to all family members |

**If you can't use pg_cron:** set `DISABLE_CRON_JOBS=true` and use an external cron service (e.g., [cron-job.org](https://cron-job.org)) to call `/api/family/check-reminders` and `/api/family/daily-schedule` on a schedule.

---

## Step 8: Set Up Telegram Webhook

After deploying, register your webhook URL with Telegram:

```bash
curl -X POST "https://api.telegram.org/bot{{YOUR_BOT_TOKEN}}/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://{{YOUR_DOMAIN}}/api/family/telegram-webhook"}'
```

Verify the webhook is set:
```bash
curl "https://api.telegram.org/bot{{YOUR_BOT_TOKEN}}/getWebhookInfo"
```

You should see `"url": "https://your-domain.com/api/family/telegram-webhook"` in the response.

---

## 📡 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/family/events?start=ISO&end=ISO` | List events in date range |
| POST | `/api/family/events` | Create new event |
| PUT | `/api/family/events/:id` | Update event |
| DELETE | `/api/family/events/:id` | Delete event |
| GET | `/api/family/announcements` | List announcements |
| POST | `/api/family/announcements` | Create announcement |
| DELETE | `/api/family/announcements/:id` | Delete announcement |
| POST | `/api/family/parse-event` | AI parse natural language → event |
| GET/POST | `/api/family/check-reminders` | Check and send due reminders |
| GET/POST | `/api/family/daily-schedule` | Send today's schedule via Telegram |
| POST | `/api/family/telegram-webhook` | Telegram bot webhook |

---

## ⏰ Cron Jobs (Optional)

### Without Supabase pg_cron

If your plan doesn't support cron, you have alternatives:

**Option A: External cron service**

Use [cron-job.org](https://cron-job.org) (free) to call:
- `https://your-domain.com/api/family/check-reminders` every 5 minutes
- `https://your-domain.com/api/family/daily-schedule` once daily at 4:00 AM UTC


## 🔧 Troubleshooting

### "Missing Supabase configuration" error
→ Make sure `NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are set in `.env.local`

### Telegram bot not responding
→ Verify webhook is set: `curl https://api.telegram.org/bot<TOKEN>/getWebhookInfo`
→ Check your deployed URL is accessible
→ Make sure the bot token is correct in `TELEGRAM_CHAT_BOT_HAYAT_SCHEDULE`

### AI parsing not working
→ Verify `OPENAI_API_KEY` is set and has credits
→ Check API route logs for errors

### Reminders not sending
→ Check if cron jobs are running: `SELECT * FROM cron.job;` in Supabase SQL Editor
→ Verify `TELEGRAM_CHAT_ID_FAMILY` has correct chat IDs
→ Test manually: `curl https://your-domain.com/api/family/check-reminders`

### Events not showing in calendar
→ Check browser console for API errors
→ Verify Supabase tables exist and have correct schema
→ Test API directly: `curl https://your-domain.com/api/family/events`

---

## 📦 Dependencies

Add these to your `package.json`:

```bash
npm install @supabase/supabase-js date-fns lucide-react
```

The app also requires:
- `next` (16+)
- `react` / `react-dom` (19+)
- `tailwindcss` (for styling)

---

## 🚀 Quick Start Summary

```bash
# 1. Install dependencies
npm install @supabase/supabase-js date-fns lucide-react

# 2. Copy source files into your Next.js project
cp -r family-schedule-guide/src/app/* app/
cp -r family-schedule-guide/src/lib/* lib/

# 3. Copy and fill environment variables
cp family-schedule-guide/.env.example .env.local
# Edit .env.local with your Supabase, Telegram, OpenAI keys + family members

# 4. Run database migrations (in Supabase SQL Editor)
# Run migrations/001_create_family_events.sql
# Run migrations/002_create_family_announcements.sql

# 5. Run locally
npm run dev

# 6. Open http://localhost:3000/family-schedule

# 7. Push to Git & connect Vercel to the repo (see Step 7)

# 8. Set up Telegram webhook (see Step 8)

# 9. (Optional) Set up cron jobs (see Step 7.3)
```

---

**Built with ❤️ for families who want to stay organized.**
