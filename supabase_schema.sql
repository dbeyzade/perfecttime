-- Create a table for user profiles
create table if not exists public.profiles (
  id uuid references auth.users not null primary key,
  updated_at timestamp with time zone,
  username text unique,
  full_name text,
  avatar_url text,
  website text,

  constraint username_length check (char_length(username) >= 3)
);

-- Set up Row Level Security (RLS)
alter table public.profiles enable row level security;

create policy "Public profiles are viewable by everyone."
  on profiles for select
  using ( true );

create policy "Users can insert their own profile."
  on profiles for insert
  with check ( auth.uid() = id );

create policy "Users can update own profile."
  on profiles for update
  using ( auth.uid() = id );

-- Create a table for meeting sessions
create table if not exists public.sessions (
  id uuid default uuid_generate_v4() primary key,
  host_id uuid references auth.users not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  start_time timestamp with time zone not null,
  is_recording boolean default false,
  reminder_minutes integer default 0,
  status text default 'scheduled' check (status in ('scheduled', 'live', 'completed', 'cancelled'))
);

-- Set up RLS for sessions
alter table public.sessions enable row level security;

create policy "Sessions are viewable by everyone."
  on sessions for select
  using ( true );

create policy "Hosts can create sessions."
  on sessions for insert
  with check ( auth.uid() = host_id );

create policy "Hosts can update their own sessions."
  on sessions for update
  using ( auth.uid() = host_id );

-- Function to handle new user signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, avatar_url, username)
  values (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url', new.raw_user_meta_data->>'username');
  return new;
end;
$$ language plpgsql security definer;

-- Trigger the function every time a user is created
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
