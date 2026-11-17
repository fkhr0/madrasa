const { findChildren } = require("./users.repository");

function toUserJson(row, children = []) {
  return {
    id: row.id,
    name: row.name,
    role: row.role,
    email: row.email,
    phone: row.phone,
    schoolName: row.school_name,
    className: row.class_name,
    subjectName: row.subject_name,
    isActive: row.is_active,
    mustChangePassword: row.must_change_password,
    isDemo: require("../auth/demo").isDemoAccount(row.id),
    children: children.map((c) => toUserJson(c)),
  };
}

async function userWithChildren(row) {
  const children = row.role === "parent" ? await findChildren(row.id) : [];
  return toUserJson(row, children);
}

module.exports = { toUserJson, userWithChildren };
