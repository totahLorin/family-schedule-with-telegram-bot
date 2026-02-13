-- ⚠️ OPTIONAL: Only run this if your Supabase plan supports pg_cron + pg_net
-- If not available, set DISABLE_CRON_JOBS=true in your .env

-- Daily family schedule cron job at 7:00 AM Israel time (4:00 AM UTC)
-- Sends a Telegram summary of today's events every morning
-- Replace {{YOUR_APP_URL}} with your deployed app URL
select cron.schedule(
  'family-daily-schedule',
  '0 4 * * *',
  $$
  select net.http_post(
    url := '{{YOUR_APP_URL}}/api/family/daily-schedule',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb
  ) as request_id;
  $$
);

-- To verify: SELECT * FROM cron.job;
-- To remove: SELECT cron.unschedule('family-daily-schedule');
