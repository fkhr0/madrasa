// SQL for uploaded files, and who may open them.
const { query, queryOne } = require("../../db/database");

const FILE = `id, name, mime, size_bytes AS size, uploaded_by AS "uploadedBy",
  institution_id AS "institutionId"`;

async function insertFile(user, { name, mime, size }) {
  const { institutionId: _, uploadedBy: __, ...file } = await queryOne(
    `INSERT INTO files (institution_id, uploaded_by, name, mime, size_bytes)
     VALUES ($1, $2, $3, $4, $5) RETURNING ${FILE}`,
    [user.institutionId, user.id, name, mime, size],
  );
  return file;
}

function findFile(id) {
  return queryOne(`SELECT ${FILE} FROM files WHERE id = $1`, [id]);
}

/** [{ id, name, mime, size }] for the given IDs uploaded by [userId]. */
function ownFiles(userId, ids) {
  if (ids.length === 0) return Promise.resolve([]);
  return query(
    `SELECT id, name, mime, size_bytes AS size FROM files
     WHERE uploaded_by = $1 AND id = ANY($2)`,
    [userId, ids],
  );
}

/**
 * The uploader and the school office always; a teacher's attachment or
 * study material: anyone at the school and parents of the class; handed-in work: the student, their
 * parents and the subject's teacher.
 */
async function canSee(user, file) {
  if (file.uploadedBy === user.id) return true;
  if (user.role === "admin" && file.institutionId === user.institutionId) return true;

  const row = await queryOne(
    `SELECT
       EXISTS (
         SELECT 1 FROM (
           SELECT aa.file_id, a.institution_id, a.class_id FROM assignment_attachments aa
           JOIN assignments a ON a.id = aa.assignment_id
           UNION ALL
           SELECT r.file_id, r.institution_id, r.class_id FROM resources r WHERE r.file_id IS NOT NULL
         ) a
         JOIN classes c ON c.id = a.class_id
         WHERE a.file_id = $1 AND (
           a.institution_id = $3 OR
           EXISTS (SELECT 1 FROM parent_children pc JOIN users u ON u.id = pc.child_id
                   WHERE pc.parent_id = $2 AND u.institution_id = c.institution_id
                     AND u.class_name = c.name))
       ) AS attachment,
       EXISTS (
         SELECT 1 FROM submission_files sf
         JOIN assignments a ON a.id = sf.assignment_id
         LEFT JOIN class_subjects cs ON cs.class_id = a.class_id AND cs.subject_id = a.subject_id
         WHERE sf.file_id = $1 AND (
           sf.student_id = $2 OR cs.teacher_id = $2 OR
           EXISTS (SELECT 1 FROM parent_children pc
                   WHERE pc.parent_id = $2 AND pc.child_id = sf.student_id))
       ) AS handed_in`,
    [file.id, user.id, user.institutionId],
  );
  return row.attachment || row.handed_in;
}

module.exports = { insertFile, findFile, ownFiles, canSee };
