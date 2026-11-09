// Messages.
const express = require("express");
const { HttpError, validate, z } = require("../../common/http");
const { requireAuth } = require("../../common/auth-middleware");
const { transaction } = require("../../db/database");
const hub = require("../../realtime/hub");
const repo = require("./messages.repository");

const router = express.Router();
router.use(requireAuth);

// GET /messages/contacts -> [{ id, name, role, detail }]
router.get("/contacts", async (req, res) => {
  res.json(await repo.contactsOf(req.user));
});

// GET /messages/conversations
//   -> [{ id, title, subtitle, isGroup, lastMessage, lastSender, lastMessageAt, unreadCount }]
router.get("/conversations", async (req, res) => {
  const classIds = await repo.classIdsOf(req.user);
  // Class chats exist from the start, even before the first message.
  for (const classId of classIds) {
    await repo.classConversation(req.user.institutionId, classId);
  }
  res.json(await repo.conversationsOf(req.user.id, classIds));
});

// POST /messages/conversations { userId } -> { id }
// Opens the private chat with that person (the same one every time).
router.post("/conversations", async (req, res) => {
  const { userId } = validate(z.object({ userId: z.string() }), req.body);
  const contacts = await repo.contactsOf(req.user);
  if (!contacts.some((c) => c.id === userId)) {
    throw new HttpError(403, "You can't message this person from the app.");
  }
  const id = await transaction((tx) =>
    repo.directConversation(tx, req.user.institutionId, req.user.id, userId),
  );
  res.json({ id });
});

// GET /messages/conversations/:id/messages?after=ISO
//   -> [{ id, senderId, senderName, text, sentAt, isMine, edited, deleted, seen }]
//   (oldest first). Reading marks the chat as read: the writers see ✓✓.
router.get("/conversations/:id/messages", async (req, res) => {
  const conversation = await conversationOr404(req);
  const after = req.query.after
    ? validate(z.iso.datetime({ offset: true }), req.query.after)
    : null;

  const messages = await repo.messagesOf(conversation.id, after);
  await markRead(conversation, req.user.id);
  res.json(messages.map((m) => ({ ...m, isMine: m.senderId === req.user.id })));
});

// POST /messages/conversations/:id/messages { text } -> message
router.post("/conversations/:id/messages", async (req, res) => {
  const conversation = await conversationOr404(req);
  const { text } = validate(
    z.object({ text: z.string().trim().min(1, "write a message").max(2000) }),
    req.body,
  );
  const message = await repo.insertMessage(conversation.id, req.user.id, text);
  await repo.markRead(conversation.id, req.user.id);
  const members = await repo.membersOf(conversation);
  // Open apps add it at once (and show a banner outside this chat).
  hub.publish(members, {
    type: "message.new",
    conversationId: conversation.id,
    senderId: req.user.id,
    senderName: message.senderName,
    preview: text.slice(0, 120),
  });
  // Phones with the app closed: a notification (not kept in the bell list:
  // the chat is where messages live).
  const others = members.filter((id) => id !== req.user.id);
  const title =
    conversation.kind === "class"
      ? `${message.senderName} · ${(await repo.classNameOf(conversation.classId)) ?? ""}`
      : message.senderName;
  pushOnly(others, title, text.slice(0, 200), `/messages/${conversation.id}`);
  res.status(201).json({ ...message, isMine: true });
});

// PATCH /messages/conversations/:id/messages/:messageId { text } -> message
// The writer, within EDIT_MINUTES of sending.
router.patch("/conversations/:id/messages/:messageId", async (req, res) => {
  const conversation = await conversationOr404(req);
  const message = await ownMessageOr404(req, conversation);
  const { text } = validate(
    z.object({ text: z.string().trim().min(1, "write a message").max(2000) }),
    req.body,
  );
  if (Date.now() - new Date(message.sentAt) > EDIT_MINUTES * 60_000) {
    throw new HttpError(409, "Messages can only be edited in the first {0} minutes.", [EDIT_MINUTES]);
  }
  await repo.editMessage(message.id, text);
  const changed = await repo.findMessage(conversation.id, message.id);
  hub.publish(await repo.membersOf(conversation), {
    type: "message.changed",
    conversationId: conversation.id,
    messageId: message.id,
  });
  res.json({ ...changed, isMine: true });
});

// DELETE /messages/conversations/:id/messages/:messageId -> 204
// The writer, any time: deleted for everyone.
router.delete("/conversations/:id/messages/:messageId", async (req, res) => {
  const conversation = await conversationOr404(req);
  const message = await ownMessageOr404(req, conversation);
  await repo.deleteMessage(message.id);
  hub.publish(await repo.membersOf(conversation), {
    type: "message.changed",
    conversationId: conversation.id,
    messageId: message.id,
  });
  res.status(204).end();
});

// POST /messages/conversations/:id/read -> 204
router.post("/conversations/:id/read", async (req, res) => {
  const conversation = await conversationOr404(req);
  await markRead(conversation, req.user.id);
  res.status(204).end();
});

/** How long a message can still be edited. */
const EDIT_MINUTES = 15;

/** Read up to now; the others' apps turn their ticks to ✓✓. */
async function markRead(conversation, userId) {
  await repo.markRead(conversation.id, userId);
  const others = (await repo.membersOf(conversation)).filter((id) => id !== userId);
  hub.publish(others, { type: "messages.seen", conversationId: conversation.id });
}

/** A message of this chat written by this user (404 otherwise). */
async function ownMessageOr404(req, conversation) {
  const message = await repo.findMessage(conversation.id, req.params.messageId);
  if (!message || message.senderId !== req.user.id || message.deleted) {
    throw new HttpError(404, "Message not found.");
  }
  return message;
}

/** A push to phones (app closed), in each phone's language; no bell entry. */
function pushOnly(userIds, title, body, route) {
  if (userIds.length === 0) return;
  const texts = { en: { title, body }, ar: { title, body } };
  require("../../jobs/queue")
    .enqueue("push.send", { userIds, texts, route })
    .catch(() => {});
}

/** The chat, if this user is in it (404 otherwise, so chats can't be probed). */
async function conversationOr404(req) {
  const conversation = await repo.findConversation(req.params.id);
  const allowed =
    conversation &&
    (conversation.kind === "direct"
      ? await repo.isMember(conversation.id, req.user.id)
      : (await repo.classIdsOf(req.user)).includes(conversation.classId));
  if (!allowed) throw new HttpError(404, "Conversation not found.");
  return conversation;
}

module.exports = router;
