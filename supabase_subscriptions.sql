-- Create subscriptions table
create table if not exists public.subscriptions (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users not null unique,
  plan_type text not null check (plan_type in ('free', 'monthly', 'yearly', 'lifetime')),
  status text not null default 'active' check (status in ('active', 'cancelled', 'expired')),
  starts_at timestamp with time zone default timezone('utc'::text, now()),
  ends_at timestamp with time zone,
  renewal_date timestamp with time zone,
  price_paid numeric,
  currency text default 'USD',
  created_at timestamp with time zone default timezone('utc'::text, now()),
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

-- Create usage tracking table
create table if not exists public.usage_tracking (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references auth.users not null,
  usage_count integer default 0,
  reset_date timestamp with time zone default timezone('utc'::text, now()),
  created_at timestamp with time zone default timezone('utc'::text, now()),
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

-- Create pricing plans table
create table if not exists public.pricing_plans (
  id uuid default uuid_generate_v4() primary key,
  plan_type text not null unique check (plan_type in ('monthly', 'yearly', 'lifetime')),
  price numeric not null,
  currency text default 'USD',
  free_uses integer default 10,
  description text,
  stripe_price_id text,
  revenucat_id text,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- Set up Row Level Security (RLS)
alter table public.subscriptions enable row level security;
alter table public.usage_tracking enable row level security;
alter table public.pricing_plans enable row level security;

-- Subscription policies
create policy "Users can view their own subscription."
  on subscriptions for select
  using ( auth.uid() = user_id );

create policy "Users can insert their own subscription."
  on subscriptions for insert
  with check ( auth.uid() = user_id );

create policy "Users can update their own subscription."
  on subscriptions for update
  using ( auth.uid() = user_id );

-- Usage tracking policies
create policy "Users can view their own usage."
  on usage_tracking for select
  using ( auth.uid() = user_id );

create policy "Users can insert their own usage."
  on usage_tracking for insert
  with check ( auth.uid() = user_id );

create policy "Users can update their own usage."
  on usage_tracking for update
  using ( auth.uid() = user_id );

-- Pricing plans policies
create policy "Pricing plans are viewable by everyone."
  on pricing_plans for select
  using ( true );

-- Insert default pricing plans
insert into public.pricing_plans (plan_type, price, currency, description, free_uses) values
  ('monthly', 20, 'USD', 'Aylık Üyelik - Her ay $20', 10),
  ('yearly', 150, 'USD', 'Yıllık Üyelik - Yıl başına $150', 10),
  ('lifetime', 200, 'USD', 'Ömür Boyu Üyelik - Tek seferlik $200', 10)
on conflict do nothing;

-- Create a function to initialize user subscription on signup
create or replace function public.initialize_user_subscription()
returns trigger as $$
begin
  insert into public.subscriptions (user_id, plan_type, status)
  values (new.id, 'free', 'active');
  
  insert into public.usage_tracking (user_id, usage_count)
  values (new.id, 0);
  
  return new;
end;
$$ language plpgsql security definer;

-- Trigger the function every time a user is created
drop trigger if exists on_auth_user_subscription_created on auth.users;
create trigger on_auth_user_subscription_created
  after insert on auth.users
  for each row execute procedure public.initialize_user_subscription();
