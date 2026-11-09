// A student's fees worked out from their account, the same way the app does
// (lib/features/finance/models/student_account_model.dart).
const { msg } = require("../../i18n");

/** tuition − discount + bus fee. */
function totalOf(account) {
  const discount = Math.round((account.tuition * account.discountPercent) / 100);
  return account.tuition + account.busFee - discount;
}

function paidOf(account) {
  return account.payments.reduce((sum, p) => sum + p.amount, 0);
}

/**
 * The total split evenly over the due dates, rounded to 1,000 dinars as
 * offices do; the last installment takes the rounding.
 * [{ dueDate: "YYYY-MM-DD", amount }]
 */
function installmentsOf(account) {
  const total = totalOf(account);
  const n = account.dueDates.length;
  const part = Math.round(total / n / 1000) * 1000;
  return account.dueDates.map((dueDate, i) => ({
    dueDate,
    amount: i === n - 1 ? total - part * (n - 1) : part,
  }));
}

/** What should have been paid by [today] but wasn't. */
function overdueOf(account, today) {
  const due = installmentsOf(account)
    .filter((i) => i.dueDate <= today)
    .reduce((sum, i) => sum + i.amount, 0);
  return Math.max(0, due - paidOf(account));
}

function balanceOf(account) {
  return totalOf(account) - paidOf(account);
}

/** 1250000 → "1,250,000 IQD" / "1,250,000 د.ع", in each reader's language. */
function iqd(amount) {
  return msg("{0} IQD", amount.toLocaleString("en-US"));
}

module.exports = { totalOf, paidOf, installmentsOf, overdueOf, balanceOf, iqd };
