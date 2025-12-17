-- Create a table for meeting participants
CREATE TABLE IF NOT EXISTS public.meeting_participants (
  id uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  meeting_id text NOT NULL,
  user_id uuid REFERENCES auth.users,
  full_name text NOT NULL,
  email text NOT NULL,
  joined_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  left_at timestamp with time zone,
  is_active boolean DEFAULT true
);

-- Set up Row Level Security (RLS)
ALTER TABLE public.meeting_participants ENABLE ROW LEVEL SECURITY;

-- Everyone can view participants of a meeting
CREATE POLICY "Participants are viewable by everyone."
  ON meeting_participants FOR SELECT
  USING ( true );

-- Users can insert themselves as participants
CREATE POLICY "Users can join as participants."
  ON meeting_participants FOR INSERT
  WITH CHECK ( auth.uid() = user_id OR user_id IS NULL );

-- Users can update their own participant record
CREATE POLICY "Users can update own participant record."
  ON meeting_participants FOR UPDATE
  USING ( auth.uid() = user_id );

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_meeting_participants_meeting_id ON meeting_participants(meeting_id);
CREATE INDEX IF NOT EXISTS idx_meeting_participants_user_id ON meeting_participants(user_id);

-- Add shared_with_user_ids column to file_shares table for selective sharing
ALTER TABLE public.file_shares ADD COLUMN IF NOT EXISTS shared_with_user_ids text[] DEFAULT NULL;
ALTER TABLE public.file_shares ADD COLUMN IF NOT EXISTS shared_with_all boolean DEFAULT true;
