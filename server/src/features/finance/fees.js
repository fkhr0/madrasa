const { msg } = require("../../i18n");

function totalOf(account) {
  const discount = Math.round((account.tuition * account.discountPercent) / 100);
  return account.tuition + account.busFee - discount;
}

function paidOf(account) {
  return account.payments.reduce((sum, p) => sum + p.amount, 0);
}

function installmentsOf(account) {
  const total = totalOf(account);
  const n = account.dueDates.length;
  const part = Math.round(total / n / 1000) * 1000;
  return account.dueDates.map((dueDate, i) => ({
    dueDate,
    amount: i === n - 1 ? total - part * (n - 1) : part,
  }));
}

function overdueOf(account, today) {
  const due = installmentsOf(account)
    .filter((i) => i.dueDate <= today)
    .reduce((sum, i) => sum + i.amount, 0);
  return Math.max(0, due - paidOf(account));
}

function balanceOf(account) {
  return totalOf(account) - paidOf(account);
}

function iqd(amount) {
  return msg("{0} IQD", amount.toLocaleString("en-US"));
}

module.exports = { totalOf, paidOf, installmentsOf, overdueOf, balanceOf, iqd };
