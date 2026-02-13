-- ⚠️ OPTIONAL: Only run this if your Supabase plan supports pg_cron + pg_net
-- (Pro plan and above, or self-hosted with these extensions enabled)
-- If not available, set DISABLE_CRON_JOBS=true in your .env

-- Enable pg_cron and pg_net extensions
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

-- Schedule reminder checks every 5 minutes
-- Replace {{YOUR_APP_URL}} with your deployed app URL
select cron.schedule(
  'family-schedule-reminders',
  '*/5 * * * *',
  $$
  select
    net.http_post(
      url := '{{YOUR_APP_URL}}/api/family/check-reminders',
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := '{}'::jsonb,
      timeout_milliseconds := 30000
    ) as request_id;
  $$
);

-- To verify: SELECT * FROM cron.job WHERE jobname = 'family-schedule-reminders';
-- To remove: SELECT cron.unschedule('family-schedule-reminders');
