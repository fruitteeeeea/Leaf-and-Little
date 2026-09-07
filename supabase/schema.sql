-- Leaf & Little public completion leaderboard
-- Run this entire file once in the Supabase SQL Editor.

create table if not exists public.garden_completions (
  id uuid primary key default gen_random_uuid(),
  player_name text not null,
  player_key text generated always as (lower(btrim(player_name))) stored,
  best_shots integer not null check (best_shots >= 1 and best_shots <= 10000),
  best_completed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint garden_completions_player_name_length check (char_length(btrim(player_name)) between 1 and 20),
  constraint garden_completions_player_key_unique unique (player_key)
);

create index if not exists garden_completions_ranking_idx
  on public.garden_completions (best_shots asc, best_completed_at asc);
create index if not exists garden_completions_recent_idx
  on public.garden_completions (best_completed_at desc);

alter table public.garden_completions enable row level security;

-- The browser may read exactly the public leaderboard data.
drop policy if exists "Public can read garden leaderboard" on public.garden_completions;
create policy "Public can read garden leaderboard"
  on public.garden_completions for select
  to anon
  using (true);

-- No direct anonymous inserts, updates, or deletes are granted. The function
-- below is the only public write path and only accepts a player's best score.
revoke all on table public.garden_completions from anon;
grant select (player_name, best_shots, best_completed_at) on table public.garden_completions to anon;

create or replace function public.submit_garden_completion(
  p_player_name text,
  p_shots integer
)
returns table (
  outcome text,
  player_name text,
  best_shots integer,
  best_completed_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := btrim(coalesce(p_player_name, ''));
  v_key text;
  v_record public.garden_completions%rowtype;
begin
  if char_length(v_name) not between 1 and 20 then
    raise exception '昵称需要 1 至 20 个字符';
  end if;
  if p_shots is null or p_shots < 1 or p_shots > 10000 then
    raise exception '成绩无效';
  end if;

  v_key := lower(v_name);
  -- Serialise submissions for the same nickname so concurrent browser requests
  -- cannot race the unique player_key constraint.
  perform pg_advisory_xact_lock(hashtext(v_key));
  select * into v_record
  from public.garden_completions
  where player_key = v_key
  for update;

  if not found then
    insert into public.garden_completions (player_name, best_shots)
    values (v_name, p_shots)
    returning * into v_record;
    return query select 'created'::text, v_record.player_name, v_record.best_shots, v_record.best_completed_at;
    return;
  end if;

  if p_shots < v_record.best_shots then
    update public.garden_completions
    set player_name = v_name,
        best_shots = p_shots,
        best_completed_at = now(),
        updated_at = now()
    where id = v_record.id
    returning * into v_record;
    return query select 'improved'::text, v_record.player_name, v_record.best_shots, v_record.best_completed_at;
    return;
  end if;

  return query select 'unchanged'::text, v_record.player_name, v_record.best_shots, v_record.best_completed_at;
end;
$$;

revoke all on function public.submit_garden_completion(text, integer) from public;
grant execute on function public.submit_garden_completion(text, integer) to anon;
