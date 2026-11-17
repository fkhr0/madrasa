const { defineJob, schedule } = require("./queue");
const reminders = require("./reminders");
const { feeReminders } = require("./fees");
const { nightly } = require("./upkeep");
const { dailySummary, weeklySummary } = require("./summaries");
const { sendDueAnnouncements } = require("../features/announcements/announce");
const { sendPush } = require("../features/notifications/push");
const { sendToPhones } = require("../features/notifications/fcm");

function registerJobs() {
  defineJob("announcements.due", sendDueAnnouncements);
  schedule("announcements.due", "* * * * *");

  defineJob("reminders.examsToday", reminders.examsToday);
  schedule("reminders.examsToday", "0 7 * * *");

  defineJob("reminders.evening", reminders.eveningReminders);
  schedule("reminders.evening", "0 18 * * *");

  defineJob("reminders.tasks", reminders.taskReminders);
  schedule("reminders.tasks", "* * * * *");

  defineJob("reminders.attendance", reminders.attendanceReminders);
  schedule("reminders.attendance", "*/5 7-14 * * 0-4");

  defineJob("fees.reminders", feeReminders);
  schedule("fees.reminders", "0 9 * * *");

  defineJob("summaries.daily", dailySummary);
  schedule("summaries.daily", "0 15 * * *");

  defineJob("summaries.weekly", weeklySummary);
  schedule("summaries.weekly", "0 17 * * 4");

  defineJob("upkeep.nightly", nightly);
  schedule("upkeep.nightly", "0 2 * * *");

  defineJob("demo.reset", () => require("../features/auth/demo").resetDemoSchool());
  schedule("demo.reset", "0 3 * * *");

  defineJob("push.send", ({ userIds, texts, route }) =>
    Promise.all([sendPush(userIds, { texts, route }), sendToPhones(userIds, { texts, route })]),
  );
}

module.exports = { registerJobs };
