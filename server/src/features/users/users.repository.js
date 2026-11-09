// SQL for accounts. Returns plain rows; users.mapper.js shapes them for the app.
const { query, queryOne } = require("../../db/database");

const SELECT_USER = `
  SELECT u.id, u.institution_id, u.role, u.name, u.email, u.phone,
         u.password_hash, u.class_name, u.subject_name, u.is_active,
         u.must_change_password, i.name AS school_name
  FROM users u
  JOIN institutions i ON i.id = u.institution_id`;

function findById(id) {
  return queryOne(`${SELECT_USER} WHERE u.id = $1`, [id]);
}

/** The account a "forgot password" request means: its ID, email or phone. */
function findForReset(who) {
  return queryOne(
    `${SELECT_USER}
     WHERE upper(u.id) = upper($1) OR lower(u.email) = lower($1)
        OR regexp_replace(u.phone, '[^0-9]', '', 'g') = regexp_replace($1, '[^0-9]', '', 'g')
     LIMIT 1`,
    [who],
  );
}

/** A parent's children (they may be in other schools of the platform). */
function findChildren(parentId) {
  return query(
    `${SELECT_USER}
     JOIN parent_children pc ON pc.child_id = u.id
     WHERE pc.parent_id = $1
     ORDER BY u.name`,
    [parentId],
  );
}

function updateContact(id, { email, phone }) {
  return query("UPDATE users SET email = $2, phone = $3 WHERE id = $1", [
    id,
    email,
    phone,
  ]);
}

function updatePasswordHash(id, passwordHash) {
  return query(
    `UPDATE users SET password_hash = $2, must_change_password = false
     WHERE id = $1`,
    [id, passwordHash],
  );
}

module.exports = { findById, findForReset, findChildren, updateContact, updatePasswordHash };
