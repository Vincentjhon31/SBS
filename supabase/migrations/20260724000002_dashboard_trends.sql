-- Richer superadmin dashboard: a 14-day request trend, a status
-- breakdown, top categories by request volume, and a recent-activity
-- feed. Kept as a separate RPC from superadmin_stats() (rather than
-- growing that one) so the existing stats shape/tests are untouched.
create or replace function public.superadmin_dashboard_trends()
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
declare
  daily jsonb;
  by_status jsonb;
  categories jsonb;
  activity jsonb;
begin
  if not public.is_superadmin() then
    raise exception 'only superadmins may view dashboard trends';
  end if;

  -- Last 14 days, zero-filled so the trend line has no gaps.
  select jsonb_agg(jsonb_build_object('day', d, 'count', coalesce(c.count, 0)) order by d)
  into daily
  from generate_series(current_date - interval '13 days', current_date, interval '1 day') as d
  left join (
    select created_at::date as day, count(*) as count
    from borrow_requests
    group by 1
  ) c on c.day = d;

  -- Fixed lifecycle order, zero-filled so every status always renders.
  select jsonb_agg(jsonb_build_object('status', s.status, 'count', coalesce(c.count, 0)) order by s.ord)
  into by_status
  from (values ('pending', 1), ('approved', 2), ('released', 3), ('returned', 4),
               ('closed', 5), ('rejected', 6), ('overdue', 7)) as s(status, ord)
  left join (
    select status, count(*) as count from borrow_requests group by 1
  ) c on c.status = s.status;

  -- Top 6 categories by all-time request volume.
  select coalesce(jsonb_agg(jsonb_build_object('category', category, 'count', count) order by count desc), '[]'::jsonb)
  into categories
  from (
    select coalesce(i.category, 'Uncategorized') as category, count(*) as count
    from borrow_requests r
    join items i on i.id = r.item_id
    group by 1
    order by count desc
    limit 6
  ) top;

  -- Last 8 requests across every department, borrower or guest.
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', r.id,
    'item_name', i.name,
    'status', r.status,
    'created_at', r.created_at,
    'is_guest', r.guest_borrower_id is not null,
    'borrower_name', coalesce(p.full_name, g.full_name, 'Unknown')
  ) order by r.created_at desc), '[]'::jsonb)
  into activity
  from (
    select * from borrow_requests order by created_at desc limit 8
  ) r
  join items i on i.id = r.item_id
  left join profiles p on p.id = r.borrower_id
  left join guest_borrowers g on g.id = r.guest_borrower_id;

  return jsonb_build_object(
    'daily_requests', daily,
    'requests_by_status', by_status,
    'top_categories', categories,
    'recent_activity', activity
  );
end;
$$;

revoke execute on function public.superadmin_dashboard_trends() from public, anon;
grant execute on function public.superadmin_dashboard_trends() to authenticated;
