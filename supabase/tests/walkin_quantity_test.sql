begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}';

do $$
declare
  v_item uuid;
  v_req uuid;
  v_qty int;
begin
  select id into v_item from public.items where name = 'Monobloc Chairs' limit 1;
  update public.items set quantity = 50 where id = v_item;

  -- Multi-unit walk-in is recorded at the requested count, not 1.
  select public.create_guest_borrow_request(
    v_item, 'Juan Guest', 'Purok 1', '09171234567', null,
    'Fiesta seating', now() + interval '1 hour', now() + interval '2 days',
    true, 12
  ) into v_req;
  select quantity_requested into v_qty from public.borrow_requests where id = v_req;
  if v_qty != 12 then
    raise exception 'FAIL: walk-in stored quantity % instead of 12', v_qty;
  end if;

  -- Omitting the argument still defaults to a single unit.
  select public.create_guest_borrow_request(
    v_item, 'Maria Guest', 'Purok 2', '09171234568', null,
    'One chair', now() + interval '1 hour', now() + interval '2 days', true
  ) into v_req;
  select quantity_requested into v_qty from public.borrow_requests where id = v_req;
  if v_qty != 1 then
    raise exception 'FAIL: default walk-in quantity was % instead of 1', v_qty;
  end if;

  -- Zero/negative is rejected.
  begin
    perform public.create_guest_borrow_request(
      v_item, 'Bad Guest', 'Purok 3', '09171234569', null,
      'Nothing', now() + interval '1 hour', now() + interval '2 days', true, 0
    );
    raise exception 'FAIL: quantity 0 was accepted';
  exception
    when raise_exception then
      if sqlerrm not like '%at least 1%' then raise; end if;
  end;
end $$;

reset role;
select 'WALK-IN QUANTITY TESTS PASSED' as result;
rollback;
