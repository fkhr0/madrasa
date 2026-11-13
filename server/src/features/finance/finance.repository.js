// SQL for fees, discounts and payments.
const { query, queryOne } = require("../../db/database");
const institution = require("../institution/institution.repository");

/** The school's fee settings, created empty the first time. */
async function settings(institutionId) {
  await query(
    "INSERT INTO finance_settings (institution_id) VALUES ($1) ON CONFLICT DO NOTHING",
    [institutionId],
  );
  const row = await queryOne(
    `SELECT tuition, bus_fee AS "busFee", configured,
            ARRAY(SELECT d::text FROM unnest(due_dates) d ORDER BY d) AS "dueDates"
     FROM finance_settings WHERE institution_id = $1`,
    [institutionId],
  );
  if (row.dueDates.length === 0) {
    const year = await institution.findCurrentYear(institutionId);
    row.dueDates = [year?.start ?? new Date().toISOString().slice(0, 10)];
  }
  const classTuition = await query(
    `SELECT c.id AS "classId", c.name AS "className", ct.tuition
     FROM classes c LEFT JOIN class_tuition ct ON ct.class_id = c.id
     WHERE c.institution_id = $1 ORDER BY c.name`,
    [institutionId],
  );
  return { ...row, classTuition };
}

async function saveSettings(tx, institutionId, { tuition, busFee, dueDates, classTuition }) {
  await tx.query(
    `INSERT INTO finance_settings (institution_id, tuition, bus_fee, due_dates, configured)
     VALUES ($1, $2, $3, $4::date[], true)
     ON CONFLICT (institution_id) DO UPDATE
     SET tuition = $2, bus_fee = $3, due_dates = $4::date[], configured = true`,
    [institutionId, tuition, busFee, dueDates],
  );
  for (const [classId, amount] of Object.entries(classTuition)) {
    if (amount === null) {
      await tx.query("DELETE FROM class_tuition WHERE class_id = $1", [classId]);
    } else {
      await tx.query(
        `INSERT INTO class_tuition (class_id, tuition) VALUES ($1, $2)
         ON CONFLICT (class_id) DO UPDATE SET tuition = $2`,
        [classId, amount],
      );
    }
  }
}

/**
 * Students' accounts as the app reads them (StudentAccountModel): every
 * active student of the school, or just [studentId].
 */
async function accounts(institutionId, studentId = null) {
  const fees = await settings(institutionId);
  const students = await query(
    `SELECT u.id AS "studentId", u.name AS "studentName",
            COALESCE(u.class_name, '') AS "className",
            CASE WHEN $4 THEN COALESCE(ct.tuition, $3) ELSE 0 END AS tuition,
            EXISTS (SELECT 1 FROM route_students rs WHERE rs.student_id = u.id) AS "ridesBus",
            COALESCE(d.percent, 0) AS "discountPercent", COALESCE(d.reason, '') AS "discountReason",
            p.id AS "parentId", p.name AS "parentName"
     FROM users u
     LEFT JOIN classes c ON c.institution_id = u.institution_id AND c.name = u.class_name
     LEFT JOIN class_tuition ct ON ct.class_id = c.id
     LEFT JOIN student_discounts d ON d.student_id = u.id
     LEFT JOIN LATERAL (
       SELECT pu.id, pu.name FROM parent_children pc JOIN users pu ON pu.id = pc.parent_id
       WHERE pc.child_id = u.id ORDER BY pu.name LIMIT 1
     ) p ON true
     WHERE u.institution_id = $1 AND u.role = 'student'
       AND ($2::text IS NULL OR u.id = $2) AND (u.is_active OR u.id = $2)
     ORDER BY u.name`,
    [institutionId, studentId, fees.tuition, fees.configured],
  );
  if (students.length === 0) return [];

  const payments = await query(
    `SELECT id, receipt_number AS "receiptNumber", student_id AS "studentId", amount,
            paid_at AS date, method, note
     FROM payments WHERE student_id = ANY($1) AND voided_at IS NULL
     ORDER BY paid_at`,
    [students.map((s) => s.studentId)],
  );

  return students.map(({ ridesBus, ...s }) => ({
    ...s,
    parentId: s.parentId ?? "",
    parentName: s.parentName ?? "",
    busFee: ridesBus && fees.configured ? fees.busFee : 0,
    feesSet: fees.configured,
    dueDates: fees.dueDates,
    payments: payments.filter((p) => p.studentId === s.studentId),
  }));
}

async function setDiscount(studentId, { percent, reason }) {
  if (percent === 0) {
    await query("DELETE FROM student_discounts WHERE student_id = $1", [studentId]);
    return;
  }
  await query(
    `INSERT INTO student_discounts (student_id, percent, reason) VALUES ($1, $2, $3)
     ON CONFLICT (student_id) DO UPDATE SET percent = $2, reason = $3`,
    [studentId, percent, reason],
  );
}

/** Records a payment with the school's next receipt number, e.g. RCP-2026-0042. */
async function insertPayment(tx, institutionId, studentId, { amount, method, note }, recordedBy) {
  const year = new Date().getFullYear();
  const { n } = await tx.queryOne(
    `SELECT COUNT(*)::int + 1 AS n FROM payments
     WHERE institution_id = $1 AND receipt_number LIKE $2`,
    [institutionId, `RCP-${year}-%`],
  );
  return tx.queryOne(
    `INSERT INTO payments (institution_id, student_id, receipt_number, amount, method, note, recorded_by)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING id, receipt_number AS "receiptNumber", student_id AS "studentId", amount,
               paid_at AS date, method, note`,
    [institutionId, studentId, `RCP-${year}-${String(n).padStart(4, "0")}`, amount, method, note, recordedBy],
  );
}

function findPayment(institutionId, id) {
  return queryOne(
    `SELECT id, student_id AS "studentId", amount, receipt_number AS "receiptNumber",
            voided_at AS "voidedAt"
     FROM payments WHERE institution_id = $1 AND id = $2`,
    [institutionId, id],
  );
}

function voidPayment(id, reason) {
  return query(
    "UPDATE payments SET voided_at = now(), void_reason = $2 WHERE id = $1",
    [id, reason],
  );
}

async function hasAnyPayments() {
  return Boolean(await queryOne("SELECT 1 AS yes FROM payments LIMIT 1"));
}

module.exports = {
  settings,
  saveSettings,
  accounts,
  setDiscount,
  insertPayment,
  findPayment,
  voidPayment,
  hasAnyPayments,
};
