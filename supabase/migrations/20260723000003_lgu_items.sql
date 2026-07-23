-- Realistic LGU-borrowable registry, filled out beyond the handful of
-- original smoke-test items. Motor Pool = vehicles; General Services
-- Office (GSO) = general equipment/tools; venues, sports gear, and
-- medical/emergency items are left unassigned (shared LGU pool) since no
-- dedicated Sports/MDRRMO department exists yet. Keyed to Vincent's known
-- profile row (same anchor as the superadmin bootstrap) rather than a
-- hardcoded UUID, so this applies identically on local and hosted.
do $$
declare
  v_id uuid;
  motor_pool_id uuid;
  gso_id uuid;
begin
  select id into v_id from public.profiles where full_name = 'Vincent Jhon';
  if v_id is null then
    return; -- environment without that seeded account; skip quietly
  end if;

  select id into motor_pool_id from public.departments where name = 'Motor Pool';
  select id into gso_id from public.departments where name = 'General Services Office';

  insert into public.items (name, distinguishing_tag, category, owning_department_id, created_by)
  values
    ('Ambulance', null, 'Vehicle', motor_pool_id, v_id),
    ('Fire Truck', null, 'Vehicle', motor_pool_id, v_id),
    ('Dump Truck', null, 'Vehicle', motor_pool_id, v_id),
    ('Garbage Truck', null, 'Vehicle', motor_pool_id, v_id),
    ('Passenger Van', null, 'Vehicle', motor_pool_id, v_id),
    ('Service Patrol Vehicle', null, 'Vehicle', motor_pool_id, v_id),
    ('Water Tanker Truck', null, 'Vehicle', motor_pool_id, v_id),
    ('Backhoe', null, 'Vehicle', motor_pool_id, v_id),
    ('Multi-Purpose Hall', null, 'Venue', null, v_id),
    ('Barangay Covered Court', null, 'Venue', null, v_id),
    ('Municipal Session Hall', null, 'Venue', null, v_id),
    ('Municipal Plaza', null, 'Venue', null, v_id),
    ('Generator Set', null, 'Equipment', gso_id, v_id),
    ('LED Wall Screen', null, 'Equipment', gso_id, v_id),
    ('Canopy Tent', null, 'Equipment', gso_id, v_id),
    ('Foldable Tables', null, 'Equipment', gso_id, v_id),
    ('Monobloc Chairs', null, 'Equipment', gso_id, v_id),
    ('Stage Platform', null, 'Equipment', gso_id, v_id),
    ('Stage Lighting Set', null, 'Equipment', gso_id, v_id),
    ('LCD Projector', null, 'Equipment', null, v_id),
    ('Videoke Machine', null, 'Equipment', null, v_id),
    ('Public Address System', null, 'Equipment', null, v_id),
    ('Chainsaw', null, 'Tool', gso_id, v_id),
    ('Grass Cutter', null, 'Tool', gso_id, v_id),
    ('Water Pump', null, 'Tool', gso_id, v_id),
    ('Volleyball Set', null, 'Sports Equipment', null, v_id),
    ('Basketball Set', null, 'Sports Equipment', null, v_id),
    ('Badminton Set', null, 'Sports Equipment', null, v_id),
    ('Stretcher', null, 'Medical/Emergency', null, v_id),
    ('Wheelchair', null, 'Medical/Emergency', null, v_id),
    ('First Aid Kit', null, 'Medical/Emergency', null, v_id)
  on conflict do nothing;
end $$;
