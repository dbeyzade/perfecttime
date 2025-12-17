-- OPSIYONEL: Gelecekte istatistik ve raporlama için eklenebilecek kolonlar
-- Şu an çalışması için bunları çalıştırmanıza gerek YOK!

-- meeting_participants tablosuna ek bilgiler
ALTER TABLE public.meeting_participants 
  ADD COLUMN IF NOT EXISTS device_info text,
  ADD COLUMN IF NOT EXISTS ip_address text,
  ADD COLUMN IF NOT EXISTS join_source text DEFAULT 'app'; -- 'app', 'web', 'link'

-- meetings tablosuna istatistik için
ALTER TABLE public.meetings 
  ADD COLUMN IF NOT EXISTS total_participants integer DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ended_at timestamp with time zone;

-- Katılımcı sayısını otomatik güncelleyen trigger (opsiyonel)
CREATE OR REPLACE FUNCTION update_participant_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE meetings 
  SET total_participants = (
    SELECT COUNT(*) 
    FROM meeting_participants 
    WHERE meeting_id = NEW.meeting_id
  )
  WHERE id = NEW.meeting_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger oluştur (opsiyonel)
DROP TRIGGER IF EXISTS participant_count_trigger ON meeting_participants;
CREATE TRIGGER participant_count_trigger
AFTER INSERT ON meeting_participants
FOR EACH ROW
EXECUTE FUNCTION update_participant_count();
