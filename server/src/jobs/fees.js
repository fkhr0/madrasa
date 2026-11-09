// Fee reminders for parents, every morning at 9:00: 3 days before an
// installment is due (if it isn't paid) every Sunday while money is overdue
// Each once (sent_reminders); paid-up families never hear from this.
const { query } = require("../db/database");
const { notify } = require("../features/notifications/notify");
const finance = require("../features/finance/finance.repository");
const fees = require("../features/finance/fees");
const { today, addDays, weekdayOf } = require("../features/attendance/school-days");
const { once } = require("./reminders");
const { msg } = require("../i18n");

const DAYS_BEFORE = 3;
const SUNDAY = 7;

async function feeReminders({ date = today() } = {}) {
  const soon = addDays(date, DAYS_BEFORE);
  let sent = 0;

  for (const { id } of await query("SELECT id FROM institutions")) {
    for (const account of await finance.accounts(id)) {
      if (!account.parentId || fees.balanceOf(account) <= 0) continue;
      const tell = (key, title, body) =>
        once(key).then(async (first) => {
          if (!first) return;
          await notify(id, [account.parentId], { type: "payment", title, body, route: "/fees" });
          sent++;
        });

      // An installment due in 3 days that isn't covered yet.
      const installments = fees.installmentsOf(account);
      const paid = fees.paidOf(account);
      let before = 0; // what the earlier installments add up to
      for (const i of installments) {
        // Payments fill installments in order, oldest first.
        const covered = Math.min(i.amount, Math.max(0, paid - before));
        const left = i.amount - covered;
        before += i.amount;
        if (i.dueDate === soon && left > 0) {
          await tell(
            `fee-soon:${account.studentId}:${i.dueDate}`,
            msg("School fees due in {0} days", DAYS_BEFORE),
            msg("{0} for {1} by {2}.", fees.iqd(left), account.studentName, i.dueDate),
          );
        }
      }

      // Overdue: once a week, on Sunday.
      const overdue = fees.overdueOf(account, date);
      if (overdue > 0 && weekdayOf(date) === SUNDAY) {
        await tell(
          `fee-overdue:${account.studentId}:${date}`,
          msg("School fees: {0} overdue", fees.iqd(overdue)),
          msg("For {0}. You can pay at the school office or by bank transfer.", account.studentName),
        );
      }
    }
  }
  return sent;
}

module.exports = { feeReminders };
