-- Messages can be edited (for a short while) and deleted by their writer.
-- A deleted message keeps its place ("This message was deleted"), not its text.
ALTER TABLE messages ADD COLUMN edited_at TIMESTAMPTZ(3);
ALTER TABLE messages ADD COLUMN deleted_at TIMESTAMPTZ(3);
