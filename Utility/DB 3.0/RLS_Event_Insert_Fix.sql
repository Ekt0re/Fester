-- Fix missing INSERT policy for event table
-- This allows any authenticated user to create an event
-- The check ensures they can only create events where they are listed as the creator

CREATE POLICY event_insert_authenticated ON event
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid()::uuid = created_by
);
