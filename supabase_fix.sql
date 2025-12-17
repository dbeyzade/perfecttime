-- Bu kod mevcut tabloyu silmeden GÜNCELLER.
-- Hata almamak için "if not exists" komutlarını kullanıyoruz.

-- 1. Tablo varsa dokunma, yoksa oluştur (ama zaten var hatası aldığın için burayı atlayacak)
create table if not exists public.profiles (
  id uuid references auth.users on delete cascade not null primary key,
  updated_at timestamp with time zone,
  username text unique,
  full_name text,
  phone_number text,
  constraint username_length check (char_length(username) >= 3)
);

-- 2. Eğer tablo zaten varsa ve sütunlar eksikse onları ekle
alter table public.profiles add column if not exists full_name text;
alter table public.profiles add column if not exists phone_number text;

-- 3. RLS Politikalarını güvenli bir şekilde oluştur (varsa silip yeniden oluşturur)
alter table public.profiles enable row level security;

do $$ 
begin
    if not exists (select 1 from pg_policies where policyname = 'Public profiles are viewable by everyone.') then
        create policy "Public profiles are viewable by everyone." on public.profiles for select using (true);
    end if;

    if not exists (select 1 from pg_policies where policyname = 'Users can insert their own profile.') then
        create policy "Users can insert their own profile." on public.profiles for insert with check (auth.uid() = id);
    end if;

    if not exists (select 1 from pg_policies where policyname = 'Users can update own profile.') then
        create policy "Users can update own profile." on public.profiles for update using (auth.uid() = id);
    end if;
end $$;

-- 4. Fonksiyonu Güncelle (Create or Replace zaten var olanı günceller)
create or replace function public.handle_new_user() 
returns trigger as $$
begin
  insert into public.profiles (id, username, full_name, phone_number)
  values (
    new.id, 
    new.raw_user_meta_data->>'username', 
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'phone_number'
  )
  on conflict (id) do update set
    username = excluded.username,
    full_name = excluded.full_name,
    phone_number = excluded.phone_number;
  return new;
end;
$$ language plpgsql security definer;

-- 5. Trigger'ı güvenli şekilde oluştur
-- Önce varsa trigger'ı kaldırıyoruz ki hata vermesin
drop trigger if exists on_auth_user_created on auth.users;

-- Sonra tekrar oluşturuyoruz
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
