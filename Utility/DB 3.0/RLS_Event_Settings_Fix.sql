-- Fix missing INSERT policy for event_settings table
-- This allows authenticated users to create settings for events they created
-- or where they have sufficient staff level (>= 3)

CREATE POLICY event_settings_insert_staff ON event_settings
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM event_staff es
        WHERE es.event_id = event_settings.event_id
          AND es.staff_user_id = auth.uid()::uuid
          AND public._role_rank(public.es_role_name(es.role_id)) >= 3
    )
    OR
    -- Allow creator of the event to insert settings even if not yet in event_staff
    -- (though usually they are added immediately)
    EXISTS (
        SELECT 1 FROM event e
        WHERE e.id = event_settings.event_id
          AND e.created_by = auth.uid()::uuid
    )
);
