-- ================================================
-- RLS POLICIES PER NOTIFICATIONS
-- ================================================

-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policy: Staff can view own notifications
CREATE POLICY "Staff can view own notifications"
  ON notifications FOR SELECT
  USING (staff_user_id = auth.uid());

-- Policy: Staff can create own notifications
CREATE POLICY "Staff can create own notifications"
  ON notifications FOR INSERT
  WITH CHECK (staff_user_id = auth.uid());

-- Policy: Staff can update own notifications (mark as read)
CREATE POLICY "Staff can update own notifications"
  ON notifications FOR UPDATE
  USING (staff_user_id = auth.uid())
  WITH CHECK (staff_user_id = auth.uid());

-- Policy: Staff can delete own notifications
CREATE POLICY "Staff can delete own notifications"
  ON notifications FOR DELETE
  USING (staff_user_id = auth.uid());
