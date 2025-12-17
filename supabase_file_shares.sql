-- Create file_shares table for tracking shared files in meetings
CREATE TABLE IF NOT EXISTS public.file_shares (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  meeting_id UUID NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
  shared_by_user_id UUID NOT NULL REFERENCES auth.users,
  file_name TEXT NOT NULL,
  file_size BIGINT,
  file_type TEXT,
  shared_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.file_shares ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Anyone can view file shares for meetings" ON public.file_shares;
DROP POLICY IF EXISTS "Authenticated users can share files" ON public.file_shares;

-- Anyone can view file shares for a meeting
CREATE POLICY "Anyone can view file shares for meetings"
  ON file_shares FOR SELECT
  USING (true);

-- Authenticated users can share files in their meetings
CREATE POLICY "Authenticated users can share files"
  ON file_shares FOR INSERT
  WITH CHECK (auth.uid() = shared_by_user_id);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS file_shares_meeting_id_idx ON public.file_shares(meeting_id);
CREATE INDEX IF NOT EXISTS file_shares_user_id_idx ON public.file_shares(shared_by_user_id);
