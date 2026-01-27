-- Migration for Peer-to-Peer Entry Sharing
-- Enable "Proposals" (Vorschläge) logic

ALTER TABLE time_entries 
ADD COLUMN IF NOT EXISTS is_proposal BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS shared_by_user_id UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS is_locked BOOLEAN DEFAULT false;

-- Add Comment for clarity
COMMENT ON COLUMN time_entries.is_proposal IS 'If true, this entry is a proposal from a colleague and not yet accepted.';
COMMENT ON COLUMN time_entries.shared_by_user_id IS 'ID of the user who created this proposal.';
COMMENT ON COLUMN time_entries.is_locked IS 'If true, the entry cannot be edited by the owner (e.g. accepted proposal).';

-- Create Policy for Viewing Proposals
-- Users should see entries where they are the owner (user_id) OR where they created it (shared_by_user_id)
-- Note: Existing RLS usually checks (auth.uid() = user_id). We need to extend this.
-- Assuming a general "Individuals can view their own data" policy exists, we extend it or rely on existing?
-- Usually: (auth.uid() = user_id OR auth.uid() = shared_by_user_id)
-- IF you already have a policy, you might need to update it manually via Supabase Dashboard if this script is just for reference.

-- (Conceptual update for RLS - User needs to apply this in Dashboard if not running raw SQL)
-- CREATE POLICY "Users can see proposals sent by them" ON "public"."time_entries"
-- FOR SELECT USING (auth.uid() = shared_by_user_id);
