// SQL for chats, their messages and who has read what.
const { query, queryOne } = require("../../db/database");
const { t } = require("../../i18n");

// ---------- Who is who ----------

/** Classes a user belongs to: a student's class, a teacher's classes. */
async function classIdsOf(user) {
  if (user.role === "student") {
    const rows = await query(
      `SELECT c.id FROM classes c JOIN users u
         ON u.institution_id = c.institution_id AND u.class_name = c.name
       WHERE u.id = $1`,
      [user.id],
    );
    return rows.map((r) => r.id);
  }
  if (user.role === "teacher") {
    const rows = await query(
      `SELECT class_id AS id FROM class_subjects WHERE teacher_id = $1
       UNION SELECT id FROM classes WHERE homeroom_teacher_id = $1`,
      [user.id],
    );
    return rows.map((r) => r.id);
  }
  return [];
}

/**
 * Everyone [user] may start a private chat with (see messages.routes.js),
 * as [{ id, name, role, detail }], by name.
 */
async function contactsOf(user) {
  const rows = await query(
    `WITH me AS (SELECT * FROM users WHERE id = $1),
     my_classes AS (
       SELECT c.id, c.name, c.institution_id FROM classes c JOIN me
         ON c.institution_id = me.institution_id
       WHERE (me.role = 'student' AND c.name = me.class_name)
          OR (me.role = 'teacher' AND (c.homeroom_teacher_id = me.id OR EXISTS (
                SELECT 1 FROM class_subjects cs WHERE cs.class_id = c.id AND cs.teacher_id = me.id)))
     ),
     children_classes AS (
       SELECT c.id FROM parent_children pc JOIN users k ON k.id = pc.child_id
       JOIN classes c ON c.institution_id = k.institution_id AND c.name = k.class_name
       WHERE pc.parent_id = $1
     ),
     class_teachers AS (
       SELECT teacher_id AS id FROM class_subjects
       WHERE class_id IN (SELECT id FROM my_classes UNION SELECT id FROM children_classes)
         AND teacher_id IS NOT NULL
       UNION SELECT homeroom_teacher_id FROM classes
       WHERE id IN (SELECT id FROM my_classes UNION SELECT id FROM children_classes)
         AND homeroom_teacher_id IS NOT NULL
     ),
     schools AS (
       SELECT institution_id AS id FROM me
       UNION SELECT k.institution_id FROM parent_children pc JOIN users k ON k.id = pc.child_id
       WHERE pc.parent_id = $1
     )
     SELECT u.id, u.name, u.role, u.class_name AS "className", u.subject_name AS "subjectName"
     FROM users u, me
     WHERE u.is_active AND u.id <> me.id AND (
       -- The office talks to everyone at the school, and everyone to the office.
       (me.role = 'admin' AND u.institution_id = me.institution_id) OR
       (u.role = 'admin' AND u.institution_id IN (SELECT id FROM schools)) OR
       -- Teachers: colleagues, and the students and parents of their classes.
       (me.role = 'teacher' AND u.institution_id = me.institution_id AND u.role = 'teacher') OR
       (me.role = 'teacher' AND u.role = 'student' AND u.institution_id = me.institution_id
         AND u.class_name IN (SELECT name FROM my_classes)) OR
       (me.role = 'teacher' AND u.role = 'parent' AND EXISTS (
         SELECT 1 FROM parent_children pc JOIN users k ON k.id = pc.child_id
         WHERE pc.parent_id = u.id AND k.institution_id = me.institution_id
           AND k.class_name IN (SELECT name FROM my_classes))) OR
       -- Students and parents: the teachers of their (children's) classes.
       (me.role IN ('student', 'parent') AND u.id IN (SELECT id FROM class_teachers))
     )
     ORDER BY u.name`,
    [user.id],
  );
  return rows.map(({ className, subjectName, ...u }) => ({
    ...u,
    detail: detailOf(u.role, className, subjectName),
  }));
}

/** "Mathematics teacher", "Student · 5th A"… in the caller's language. */
function detailOf(role, className, subjectName) {
  switch (role) {
    case "teacher": return subjectName ? t("{0} teacher", [subjectName]) : t("Teacher");
    case "student": return className ? t("Student · {0}", [className]) : t("Student");
    case "parent": return t("Parent");
    case "admin": return t("School office");
    case "driver": return t("Bus driver");
    default: return "";
  }
}

// ---------- Conversations ----------

/** The class's group chat, created the first time it is needed. */
async function classConversation(institutionId, classId) {
  await query(
    `INSERT INTO conversations (institution_id, kind, class_id) VALUES ($1, 'class', $2)
     ON CONFLICT (class_id) DO NOTHING`,
    [institutionId, classId],
  );
  return queryOne("SELECT id FROM conversations WHERE class_id = $1", [classId]);
}

/** The private chat of two people, created if needed. */
async function directConversation(tx, institutionId, a, b) {
  // Two taps at once (a slow network) wait for each other: one chat, not two.
  await tx.query("SELECT pg_advisory_xact_lock(hashtext($1))", [`direct:${[a, b].sort().join(":")}`]);
  const found = await tx.queryOne(
    `SELECT c.id FROM conversations c
     JOIN conversation_members m1 ON m1.conversation_id = c.id AND m1.user_id = $1
     JOIN conversation_members m2 ON m2.conversation_id = c.id AND m2.user_id = $2
     WHERE c.kind = 'direct'`,
    [a, b],
  );
  if (found) return found.id;

  const { id } = await tx.queryOne(
    "INSERT INTO conversations (institution_id, kind) VALUES ($1, 'direct') RETURNING id",
    [institutionId],
  );
  for (const userId of [a, b]) {
    await tx.query(
      "INSERT INTO conversation_members (conversation_id, user_id) VALUES ($1, $2)",
      [id, userId],
    );
  }
  return id;
}

function findConversation(id) {
  return queryOne(
    `SELECT id, kind, class_id AS "classId", institution_id AS "institutionId"
     FROM conversations WHERE id = $1`,
    [id],
  );
}

async function isMember(conversationId, userId) {
  return Boolean(
    await queryOne(
      "SELECT 1 AS yes FROM conversation_members WHERE conversation_id = $1 AND user_id = $2",
      [conversationId, userId],
    ),
  );
}

/**
 * The user's chats with their last message and unread count, newest first.
 * Private chats show the other person; class chats the class.
 */
function conversationsOf(userId, classIds) {
  return query(
    `SELECT c.id, c.kind = 'class' AS "isGroup",
            COALESCE(cl.name, other.name) AS title,
            other.role AS "otherRole", other.class_name AS "otherClass",
            other.subject_name AS "otherSubject",
            last.text AS "lastMessage", last.deleted AS "lastDeleted",
            last.sender_name AS "lastSender",
            COALESCE(last.sent_at, c.created_at) AS "lastMessageAt",
            (SELECT COUNT(*)::int FROM messages m
             WHERE m.conversation_id = c.id AND m.sender_id IS DISTINCT FROM $1
               AND m.sent_at > COALESCE(
                 (SELECT read_at FROM conversation_reads r
                  WHERE r.conversation_id = c.id AND r.user_id = $1), '-infinity')
            ) AS "unreadCount"
     FROM conversations c
     LEFT JOIN classes cl ON cl.id = c.class_id
     LEFT JOIN LATERAL (
       SELECT u.name, u.role, u.class_name, u.subject_name FROM conversation_members m
       JOIN users u ON u.id = m.user_id
       WHERE m.conversation_id = c.id AND m.user_id <> $1 LIMIT 1
     ) other ON c.kind = 'direct'
     LEFT JOIN LATERAL (
       SELECT m.text, m.sent_at, m.deleted_at IS NOT NULL AS deleted, s.name AS sender_name
       FROM messages m
       LEFT JOIN users s ON s.id = m.sender_id
       WHERE m.conversation_id = c.id ORDER BY m.sent_at DESC LIMIT 1
     ) last ON true
     WHERE c.id IN (SELECT conversation_id FROM conversation_members WHERE user_id = $1)
        OR c.class_id = ANY($2)
     ORDER BY "lastMessageAt" DESC`,
    [userId, classIds],
  ).then((rows) =>
    rows.map(({ otherRole, otherClass, otherSubject, lastSender, lastDeleted, ...c }) => ({
      ...c,
      subtitle: c.isGroup ? t("Class chat") : detailOf(otherRole, otherClass, otherSubject),
      lastMessage: lastDeleted ? t("This message was deleted") : (c.lastMessage ?? ""),
      lastSender: lastSender ?? null,
    })),
  );
}

// ---------- Messages ----------

const MESSAGE = `
  SELECT m.id, m.sender_id AS "senderId", COALESCE(u.name, 'Former member') AS "senderName",
         CASE WHEN m.deleted_at IS NULL THEN m.text ELSE '' END AS text,
         m.sent_at AS "sentAt", m.edited_at IS NOT NULL AS edited,
         m.deleted_at IS NOT NULL AS deleted,
         -- Seen: someone else in the chat has read up to it (✓✓).
         EXISTS (SELECT 1 FROM conversation_reads r
                 WHERE r.conversation_id = m.conversation_id
                   AND r.user_id IS DISTINCT FROM m.sender_id AND r.read_at >= m.sent_at) AS seen
  FROM messages m LEFT JOIN users u ON u.id = m.sender_id`;

/** Oldest first; with [after] only newer ones (what is new since). */
function messagesOf(conversationId, after = null) {
  return query(
    `${MESSAGE}
     WHERE m.conversation_id = $1 AND ($2::timestamptz IS NULL OR m.sent_at > $2)
     ORDER BY m.sent_at, m.id
     LIMIT 500`,
    [conversationId, after],
  );
}

function findMessage(conversationId, messageId) {
  return queryOne(`${MESSAGE} WHERE m.conversation_id = $1 AND m.id = $2`, [
    conversationId,
    messageId,
  ]);
}

function editMessage(messageId, text) {
  return query("UPDATE messages SET text = $2, edited_at = now() WHERE id = $1", [messageId, text]);
}

/** The text is wiped, not kept: deleted means gone. */
function deleteMessage(messageId) {
  return query("UPDATE messages SET text = '', deleted_at = now() WHERE id = $1", [messageId]);
}

function insertMessage(conversationId, senderId, text) {
  return queryOne(
    `WITH m AS (
       INSERT INTO messages (conversation_id, sender_id, text) VALUES ($1, $2, $3)
       RETURNING id, sender_id, text, sent_at)
     SELECT m.id, m.sender_id AS "senderId", u.name AS "senderName", m.text,
            m.sent_at AS "sentAt", false AS edited, false AS deleted, false AS seen
     FROM m JOIN users u ON u.id = m.sender_id`,
    [conversationId, senderId, text],
  );
}

function markRead(conversationId, userId) {
  return query(
    `INSERT INTO conversation_reads (conversation_id, user_id, read_at) VALUES ($1, $2, now())
     ON CONFLICT (conversation_id, user_id) DO UPDATE SET read_at = now()`,
    [conversationId, userId],
  );
}

async function classNameOf(classId) {
  return (await queryOne("SELECT name FROM classes WHERE id = $1", [classId]))?.name ?? null;
}

/** Everyone in a chat: the two people, or a class's students and teachers. */
async function membersOf(conversation) {
  if (conversation.kind === "direct") {
    const rows = await query(
      "SELECT user_id AS id FROM conversation_members WHERE conversation_id = $1",
      [conversation.id],
    );
    return rows.map((r) => r.id);
  }
  const rows = await query(
    `SELECT u.id FROM users u JOIN classes c
       ON c.institution_id = u.institution_id AND c.name = u.class_name
     WHERE c.id = $1 AND u.role = 'student' AND u.is_active
     UNION SELECT teacher_id FROM class_subjects WHERE class_id = $1 AND teacher_id IS NOT NULL
     UNION SELECT homeroom_teacher_id FROM classes WHERE id = $1 AND homeroom_teacher_id IS NOT NULL`,
    [conversation.classId],
  );
  return rows.map((r) => r.id);
}

async function hasAnyMessages() {
  return Boolean(await queryOne("SELECT 1 AS yes FROM messages LIMIT 1"));
}

module.exports = {
  classIdsOf,
  contactsOf,
  classConversation,
  directConversation,
  findConversation,
  isMember,
  conversationsOf,
  messagesOf,
  classNameOf,
  findMessage,
  editMessage,
  deleteMessage,
  insertMessage,
  markRead,
  membersOf,
  hasAnyMessages,
};
