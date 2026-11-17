const express = require("express");
const { HttpError, validate, z } = require("../../common/http");
const { requireAuth } = require("../../common/auth-middleware");
const { transaction } = require("../../db/database");
const hub = require("../../realtime/hub");
const repo = require("./messages.repository");

const router = express.Router();
router.use(requireAuth);

router.get("/contacts", async (req, res) => {
  res.json(await repo.contactsOf(req.user));
});

router.get("/conversations", async (req, res) => {
  const classIds = await repo.classIdsOf(req.user);
  for (const classId of classIds) {
    await repo.classConversation(req.user.institutionId, classId);
  }
  res.json(await repo.conversationsOf(req.user.id, classIds));
});

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

router.get("/conversations/:id/messages", async (req, res) => {
  const conversation = await conversationOr404(req);
  const after = req.query.after
    ? validate(z.iso.datetime({ offset: true }), req.query.after)
    : null;

  const messages = await repo.messagesOf(conversation.id, after);
  await markRead(conversation, req.user.id);
  res.json(messages.map((m) => ({ ...m, isMine: m.senderId === req.user.id })));
});

router.post("/conversations/:id/messages", async (req, res) => {
  const conversation = await conversationOr404(req);
  const { text } = validate(
    z.object({ text: z.string().trim().min(1, "write a message").max(2000) }),
    req.body,
  );
  const message = await repo.insertMessage(conversation.id, req.user.id, text);
  await repo.markRead(conversation.id, req.user.id);
  const members = await repo.membersOf(conversation);
  hub.publish(members, {
    type: "message.new",
    conversationId: conversation.id,
    senderId: req.user.id,
    senderName: message.senderName,
    preview: text.slice(0, 120),
  });
  const others = members.filter((id) => id !== req.user.id);
  const title =
    conversation.kind === "class"
      ? `${message.senderName} · ${(await repo.classNameOf(conversation.classId)) ?? ""}`
      : message.senderName;
  pushOnly(others, title, text.slice(0, 200), `/messages/${conversation.id}`);
  res.status(201).json({ ...message, isMine: true });
});

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

router.post("/conversations/:id/read", async (req, res) => {
  const conversation = await conversationOr404(req);
  await markRead(conversation, req.user.id);
  res.status(204).end();
});

const EDIT_MINUTES = 15;

async function markRead(conversation, userId) {
  await repo.markRead(conversation.id, userId);
  const others = (await repo.membersOf(conversation)).filter((id) => id !== userId);
  hub.publish(others, { type: "messages.seen", conversationId: conversation.id });
}

async function ownMessageOr404(req, conversation) {
  const message = await repo.findMessage(conversation.id, req.params.messageId);
  if (!message || message.senderId !== req.user.id || message.deleted) {
    throw new HttpError(404, "Message not found.");
  }
  return message;
}

function pushOnly(userIds, title, body, route) {
  if (userIds.length === 0) return;
  const texts = { en: { title, body }, ar: { title, body } };
  require("../../jobs/queue")
    .enqueue("push.send", { userIds, texts, route })
    .catch(() => {});
}

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
