-- Enable creating time entries for other users IF they are marked as proposals
-- This allows the "Team Entry" feature where one user creates a proposal for another.

-- We use a DO block to safely drop/create without failing if it doesn't exist (though standard migrations usually just Create)
-- But standard SQL 'CREATE POLICY' doesn't support 'IF NOT EXISTS' directly in all versions, 
-- and names might conflict if manually applied. 
-- However, for a clean migration file, we usually just write the CREATE statement.
-- Assuming standard usage:

DROP POLICY IF EXISTS "Enable insert for team proposals" ON "public"."time_entries";

CREATE POLICY "Enable insert for team proposals"
ON "public"."time_entries"
FOR INSERT
TO authenticated
WITH CHECK (
  is_proposal = true
);
