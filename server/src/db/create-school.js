// A new school and its office (admin) account: the office then adds its
// classes and people in the app. On the server:
//   docker compose exec api1 node src/db/create-school.js "School name" ["Admin name"]
//   ... --sample   also a class, a subject and one account per role (testing)
// Prints each ID and a temporary password once; everyone chooses their own
// password at first sign-in.
const crypto = require("crypto");
const bcrypt = require("bcryptjs");
const config = require("../config");
const { connect, transaction, queryOne, close } = require("./database");
const repo = require("../features/people/people.repository");
const { addMissingOfficialHolidaysEverywhere } = require("../features/institution/official-holidays");
const { addDefaultPeriodsEverywhere } = require("../features/timetable/default-periods");

const PREFIX = { admin: "ADM", teacher: "TCH", student: "STU", parent: "PAR", driver: "DRV" };

function makePassword() {
  const chars = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789";
  return Array.from({ length: 10 }, () => chars[crypto.randomInt(chars.length)]).join("");
}

/** The study year we are in: 20 Sep to 10 Jun. */
function currentYear(today = new Date()) {
  const start = today.getMonth() >= 7 ? today.getFullYear() : today.getFullYear() - 1;
  return {
    name: `${start}–${start + 1}`,
    start: `${start}-09-20`,
    firstEnd: `${start + 1}-01-21`,
    secondStart: `${start + 1}-02-07`,
    end: `${start + 1}-06-10`,
  };
}

/** Makes the school and its accounts; returns them with their passwords. */
async function createSchool(name, { adminName = "مدير المدرسة", sample = false } = {}) {
  if (await queryOne("SELECT id FROM institutions WHERE name = $1", [name])) {
    throw new Error(`A school called "${name}" exists already.`);
  }

  const institutionId = `inst-${crypto.randomUUID().slice(0, 8)}`;
  const year = currentYear();
  const calendarYear = new Date().getFullYear();
  const people = [{ role: "admin", name: adminName }];
  if (sample) people.push(
    { role: "teacher", name: "مدرس الرياضيات", subjectName: "الرياضيات" },
    { role: "student", name: "طالب التجربة", className: "الأول المتوسط - أ" },
    { role: "parent", name: "ولي أمر الطالب" },
    { role: "driver", name: "سائق الحافلة", phone: "+964 770 000 0000" },
  );

  await transaction(async (tx) => {
    await tx.query(
      "INSERT INTO institutions (id, name, type, city) VALUES ($1, $2, 'school', 'Baghdad')",
      [institutionId, name],
    );
    const yearId = `year-${institutionId}`;
    await tx.query(
      `INSERT INTO academic_years (id, institution_id, name, start_date, end_date, is_current)
       VALUES ($1, $2, $3, $4, $5, true)`,
      [yearId, institutionId, year.name, year.start, year.end],
    );
    await tx.query(
      `INSERT INTO terms (academic_year_id, name, start_date, end_date) VALUES
         ($1, 'First semester', $2, $3), ($1, 'Second semester', $4, $5)`,
      [yearId, year.start, year.firstEnd, year.secondStart, year.end],
    );

    for (const person of people) {
      person.id = await repo.nextId(tx, PREFIX[person.role], calendarYear);
      person.password = makePassword();
      await repo.insertUser(tx, {
        ...person,
        email: "",
        phone: person.phone ?? "",
        institutionId,
        passwordHash: await bcrypt.hash(person.password, config.bcryptCost),
      });
    }
    if (!sample) return;
    const byRole = Object.fromEntries(people.map((p) => [p.role, p]));
    await repo.setChildren(tx, byRole.parent.id, [byRole.student.id]);

    // The teacher's subject in the student's class, with the teacher as homeroom teacher.
    const subject = await tx.queryOne(
      "INSERT INTO subjects (institution_id, name, icon, color) VALUES ($1, $2, 'math', 'blue') RETURNING id",
      [institutionId, byRole.teacher.subjectName],
    );
    const schoolClass = await tx.queryOne(
      "INSERT INTO classes (institution_id, name, homeroom_teacher_id) VALUES ($1, $2, $3) RETURNING id",
      [institutionId, byRole.student.className, byRole.teacher.id],
    );
    await tx.query(
      "INSERT INTO class_subjects (class_id, subject_id, teacher_id) VALUES ($1, $2, $3)",
      [schoolClass.id, subject.id, byRole.teacher.id],
    );
  });

  await addMissingOfficialHolidaysEverywhere();
  await addDefaultPeriodsEverywhere();
  return { institutionId, people };
}

async function main() {
  const args = process.argv.slice(2);
  const sample = args.includes("--sample");
  const [name, adminName] = args.filter((a) => a !== "--sample").map((a) => a.trim());
  if (!name) {
    console.error('Usage: node src/db/create-school.js "School name" ["Admin name"] [--sample]');
    process.exit(1);
  }
  await connect();
  const { institutionId, people } = await createSchool(name, { adminName: adminName || undefined, sample });
  console.log(`\n${name} (${institutionId}): sign in with these, then choose a new password.\n`);
  for (const p of people) console.log(`  ${p.role.padEnd(8)} ${p.id}   ${p.password}`);
  console.log("");
  await close();
}

module.exports = { createSchool };

if (require.main === module) {
  main().catch(async (err) => {
    console.error(err.message ?? err);
    await close().catch(() => {});
    process.exit(1);
  });
}
