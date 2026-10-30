-- CampusVault initial schema. Apply to a fresh Supabase project as postgres.
create extension if not exists pgcrypto;
create extension if not exists btree_gist;

create type public.app_role as enum ('student','staff','admin');
create type public.booking_status as enum ('pending','approved','rejected','waitlisted','checked_out','returned','cancelled');
create type public.incident_status as enum ('open','under_review','resolved');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (length(display_name) between 1 and 120),
  role public.app_role not null default 'student',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.resources (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references public.profiles(id),
  name text not null check(length(name) between 2 and 160), category text not null, location text not null,
  description text not null, allowed_use text not null default '', restrictions text not null default '',
  supervision text not null default '', training_required boolean not null default false,
  membership_required boolean not null default false, max_booking interval not null default interval '1 day' check(max_booking > interval '0'),
  active boolean not null default true, fictional_demo boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.eligibility_verifications (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id),
  resource_id uuid references public.resources(id), verification_type text not null check(verification_type in ('training','membership')),
  verified boolean not null, verified_by uuid not null references public.profiles(id), evidence_note text not null default '',
  created_at timestamptz not null default now(), revoked_at timestamptz
);
create index eligibility_lookup on public.eligibility_verifications(user_id,resource_id,verification_type) where verified and revoked_at is null;
create table public.bookings (
  id uuid primary key default gen_random_uuid(), resource_id uuid not null references public.resources(id),
  requester_id uuid not null references public.profiles(id), purpose text not null check(length(purpose) between 5 and 2000),
  starts_at timestamptz not null, ends_at timestamptz not null, status public.booking_status not null default 'pending',
  request_order bigint generated always as identity, decision_by uuid references public.profiles(id), decision_at timestamptz,
  decision_reason text not null default '', checked_out_by uuid references public.profiles(id), checked_out_at timestamptz,
  returned_by uuid references public.profiles(id), returned_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check(ends_at > starts_at), check(ends_at - starts_at <= interval '14 days'),
  exclude using gist(resource_id with =, tstzrange(starts_at,ends_at,'[)') with &&)
    where(status in ('approved','checked_out'))
);
create index bookings_requester_status on public.bookings(requester_id,status);
create index bookings_resource_window on public.bookings(resource_id,starts_at,ends_at);
create table public.condition_reports (
 id uuid primary key default gen_random_uuid(), booking_id uuid not null references public.bookings(id),
 report_type text not null check(report_type in ('checkout','return')), notes text not null default '',
 recorded_by uuid not null references public.profiles(id), created_at timestamptz not null default now(),
 unique(booking_id,report_type)
);
create table public.incidents (
 id uuid primary key default gen_random_uuid(), booking_id uuid references public.bookings(id), resource_id uuid references public.resources(id),
 reporter_id uuid not null references public.profiles(id), incident_type text not null, description text not null check(length(description) between 5 and 4000),
 status public.incident_status not null default 'open', resolution text not null default '', resolved_by uuid references public.profiles(id),
 created_at timestamptz not null default now(), resolved_at timestamptz
);
create table public.notifications (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id), title text not null,
 body text not null, read_at timestamptz, created_at timestamptz not null default now()
);
create table public.audit_logs (
 id bigint generated always as identity primary key, actor_id uuid references public.profiles(id),
 entity_type text not null, entity_id uuid, action text not null, details jsonb not null default '{}',
 created_at timestamptz not null default now()
);
create index audit_recent on public.audit_logs(created_at desc);

create function public.current_role() returns public.app_role language sql stable security definer set search_path=public as $$
 select role from public.profiles where id=auth.uid()
$$;
create function public.is_staff() returns boolean language sql stable security definer set search_path=public as $$
 select coalesce(public.current_role() in ('staff','admin'),false)
$$;
create function public.audit_row() returns trigger language plpgsql security definer set search_path=public as $$
declare rid uuid; begin
 rid := case when tg_op='DELETE' then old.id else new.id end;
 insert into public.audit_logs(actor_id,entity_type,entity_id,action,details)
 values(auth.uid(),tg_table_name,rid,lower(tg_op),jsonb_build_object('at',now()));
 return case when tg_op='DELETE' then old else new end;
end $$;
create trigger resources_audit after insert or update or delete on public.resources for each row execute function public.audit_row();
create trigger bookings_audit after insert or update or delete on public.bookings for each row execute function public.audit_row();
create trigger incidents_audit after insert or update or delete on public.incidents for each row execute function public.audit_row();
create function public.check_approval() returns trigger language plpgsql security definer set search_path=public as $$
declare res public.resources%rowtype; active_count integer; begin
 if new.status='approved' and (tg_op='INSERT' or old.status is distinct from new.status) then
   if not public.is_staff() then raise exception 'Only staff can approve requests'; end if;
   if new.requester_id=auth.uid() then raise exception 'Users cannot approve their own requests'; end if;
   select * into res from public.resources where id=new.resource_id and active;
   if not found then raise exception 'Resource is unavailable'; end if;
   if res.training_required and not exists(select 1 from public.eligibility_verifications v where v.user_id=new.requester_id and (v.resource_id is null or v.resource_id=res.id) and v.verification_type='training' and v.verified and v.revoked_at is null) then raise exception 'Required training is not verified'; end if;
   if res.membership_required and not exists(select 1 from public.eligibility_verifications v where v.user_id=new.requester_id and (v.resource_id is null or v.resource_id=res.id) and v.verification_type='membership' and v.verified and v.revoked_at is null) then raise exception 'Required membership is not verified'; end if;
   select count(*) into active_count from public.bookings where requester_id=new.requester_id and status in ('pending','approved','checked_out','waitlisted') and id<>new.id;
   if active_count>=3 then raise exception 'FairShare limit: at most three active bookings'; end if;
   new.decision_by=auth.uid(); new.decision_at=now();
 end if;
 return new;
end $$;
create trigger booking_approval_guard before insert or update of status on public.bookings for each row execute function public.check_approval();
create function public.protect_booking_transition() returns trigger language plpgsql security definer set search_path=public as $$ begin
 if auth.uid()=old.requester_id and not public.is_staff() and not (
   old.status in ('pending','waitlisted','approved') and new.status='cancelled' and
   new.requester_id=old.requester_id and new.resource_id=old.resource_id and
   new.starts_at=old.starts_at and new.ends_at=old.ends_at and new.purpose=old.purpose
 ) then raise exception 'Requesters may only cancel their own active booking'; end if;
 if new.status is distinct from old.status and not (
  (old.status='pending' and new.status in ('approved','rejected','waitlisted','cancelled')) or
  (old.status='waitlisted' and new.status in ('approved','rejected','cancelled')) or
  (old.status='approved' and new.status in ('checked_out','cancelled')) or
  (old.status='checked_out' and new.status='returned')) then raise exception 'Invalid booking status transition'; end if;
 return new;
end $$;
create trigger booking_transition_guard before update of status on public.bookings for each row execute function public.protect_booking_transition();

alter table public.profiles enable row level security; alter table public.resources enable row level security;
alter table public.eligibility_verifications enable row level security; alter table public.bookings enable row level security;
alter table public.condition_reports enable row level security; alter table public.incidents enable row level security;
alter table public.notifications enable row level security; alter table public.audit_logs enable row level security;
create policy profiles_read_self_or_staff on public.profiles for select using(id=auth.uid() or public.is_staff());
create policy profiles_update_self_name on public.profiles for update using(id=auth.uid()) with check(id=auth.uid() and role=public.current_role());
create policy resources_read_active on public.resources for select using(active or public.is_staff());
create policy resources_staff_manage on public.resources for all using(public.is_staff() and (owner_id=auth.uid() or public.current_role()='admin')) with check(public.is_staff() and (owner_id=auth.uid() or public.current_role()='admin'));
create policy eligibility_read_own_or_staff on public.eligibility_verifications for select using(user_id=auth.uid() or public.is_staff());
create policy eligibility_staff_write on public.eligibility_verifications for insert with check(public.is_staff() and verified_by=auth.uid());
create policy eligibility_admin_revoke on public.eligibility_verifications for update using(public.current_role()='admin') with check(public.current_role()='admin');
create policy bookings_read_participant_or_staff on public.bookings for select using(requester_id=auth.uid() or public.is_staff());
create policy bookings_request_self on public.bookings for insert with check(requester_id=auth.uid() and status='pending');
create policy bookings_requester_cancel on public.bookings for update using(requester_id=auth.uid()) with check(requester_id=auth.uid() and status='cancelled');
create policy bookings_staff_decide on public.bookings for update using(public.is_staff()) with check(public.is_staff());
create policy condition_read_participant_staff on public.condition_reports for select using(public.is_staff() or exists(select 1 from public.bookings b where b.id=booking_id and b.requester_id=auth.uid()));
create policy condition_staff_insert on public.condition_reports for insert with check(public.is_staff() and recorded_by=auth.uid());
create policy incidents_read_reporter_staff on public.incidents for select using(reporter_id=auth.uid() or public.is_staff());
create policy incident_report_self on public.incidents for insert with check(reporter_id=auth.uid());
create policy incident_staff_update on public.incidents for update using(public.is_staff()) with check(public.is_staff() and resolved_by=auth.uid());
create policy notifications_read_own on public.notifications for select using(user_id=auth.uid());
create policy notifications_update_own on public.notifications for update using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy audit_read_staff on public.audit_logs for select using(public.is_staff());
-- No client insert/update/delete policy for audit_logs: only security-definer triggers write entries.

-- Do not seed real identities or passwords. Create demo auth users in Supabase Dashboard,
-- then assign roles through SQL Editor as project owner (never via public signup metadata):
-- insert into public.profiles(id,display_name,role) values('<AUTH UUID>','Demo Staff','staff');
