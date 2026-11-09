// Who may see one person's school data (timetable, attendance...): the
// person, their parents, and the administrator of their school.
const { queryOne } = require("../../db/database");
const { HttpError } = require("../../common/http");

function findPerson(id) {
  return queryOne(
    `SELECT id, role, name, institution_id AS "institutionId",
            class_name AS "className"
     FROM users WHERE id = $1`,
    [id],
  );
}

async function canSee(user, person) {
  if (user.id === person.id) return true;
  if (user.role === "admin") return user.institutionId === person.institutionId;
  if (user.role === "parent") {
    return Boolean(
      await queryOne(
        "SELECT 1 AS yes FROM parent_children WHERE parent_id = $1 AND child_id = $2",
        [user.id, person.id],
      ),
    );
  }
  return false;
}

/** The person, or 404 when they don't exist or [user] may not see them. */
async function personOr404(user, id) {
  const person = await findPerson(id);
  if (!person || !(await canSee(user, person))) {
    throw new HttpError(404, "Person not found.");
  }
  return person;
}

module.exports = { personOr404 };
