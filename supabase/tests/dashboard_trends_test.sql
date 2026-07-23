-- superadmin_dashboard_trends(): auth gate + response shape.
--   docker exec -i supabase_db_SBS psql -U postgres -d postgres -v ON_ERROR_STOP=1 < supabase/tests/dashboard_trends_test.sql
-- Seed deps: Test Staff (1111..., NOT superadmin), Vincent (4444..., IS superadmin).
-- Rolled back at the end.

begin;

set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

do $$
begin
  begin
    perform public.superadmin_dashboard_trends();
    raise exception 'FAIL: non-superadmin staff could call superadmin_dashboard_trends()';
  exception
    when raise_exception then
      if sqlerrm not like '%only superadmins%' then raise; end if;
  end;
end $$;

set local request.jwt.claims = '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

do $$
declare trends jsonb;
begin
  select public.superadmin_dashboard_trends() into trends;

  if jsonb_array_length(trends -> 'daily_requests') <> 14 then
    raise exception 'FAIL: daily_requests should have exactly 14 zero-filled days';
  end if;

  if jsonb_array_length(trends -> 'requests_by_status') <> 7 then
    raise exception 'FAIL: requests_by_status should have exactly 7 zero-filled statuses';
  end if;

  if trends -> 'top_categories' is null or trends -> 'recent_activity' is null then
    raise exception 'FAIL: trends missing top_categories or recent_activity key';
  end if;
end $$;

reset role;
select 'DASHBOARD TRENDS TESTS PASSED' as result;

rollback;
