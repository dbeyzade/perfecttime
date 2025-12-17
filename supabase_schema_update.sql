-- Update profiles table to include avatar_url
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Create sessions table
CREATE TABLE IF NOT EXISTS public.sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    host_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    start_time TIMESTAMP WITH TIME ZONE,
    title TEXT DEFAULT 'Meeting'
);

-- Enable RLS on sessions
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;

-- Allow read access to everyone (or just authenticated users)
CREATE POLICY "Public sessions are viewable by everyone" 
ON public.sessions FOR SELECT 
USING (true);

-- Allow authenticated users to insert sessions (becoming a host)
CREATE POLICY "Users can create sessions" 
ON public.sessions FOR INSERT 
WITH CHECK (auth.uid() = host_id);

-- Allow host to update their sessions
CREATE POLICY "Hosts can update their own sessions" 
ON public.sessions FOR UPDATE 
USING (auth.uid() = host_id);
