-- Create meetings table for session management
CREATE TABLE IF NOT EXISTS public.meetings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  host_id UUID REFERENCES auth.users,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  subject TEXT,
  is_recording BOOLEAN DEFAULT false,
  reminder_minutes INTEGER DEFAULT 0,
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'active', 'completed', 'cancelled')),
  join_link TEXT,
  web_link TEXT
);

-- Enable RLS
ALTER TABLE public.meetings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Anyone can view meetings" ON public.meetings;
DROP POLICY IF EXISTS "Authenticated users can create meetings" ON public.meetings;
DROP POLICY IF EXISTS "Hosts can update their own meetings" ON public.meetings;

-- Anyone can view meetings (needed for join links)
CREATE POLICY "Anyone can view meetings"
  ON meetings FOR SELECT
  USING (true);

-- Only authenticated users can create meetings
CREATE POLICY "Authenticated users can create meetings"
  ON meetings FOR INSERT
  WITH CHECK (auth.uid() = host_id);

-- Only hosts can update their own meetings
CREATE POLICY "Hosts can update their own meetings"
  ON meetings FOR UPDATE
  USING (auth.uid() = host_id);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS meetings_id_idx ON public.meetings(id);
CREATE INDEX IF NOT EXISTS meetings_host_id_idx ON public.meetings(host_id);
