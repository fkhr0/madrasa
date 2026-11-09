// Demo data: the same school, people and study year as the app's mock data,
// so the app looks the same whether it runs on mocks or on this server.
// Runs only on an empty database, and only when SEED_DEMO_DATA=true.
const bcrypt = require("bcryptjs");
const config = require("../config");
const { queryOne, transaction } = require("./database");

const NOOR = "inst-001";
const NOOR_INTERMEDIATE = "inst-002";

/** The demo schools (reset every night with "Try the demo"). */
const DEMO_SCHOOLS = [NOOR, NOOR_INTERMEDIATE];

/** "Try the demo": the account each role opens. */
const DEMO_ACCOUNTS = {
  student: "STU-2026-0142",
  parent: "PAR-2026-0142",
  teacher: "TCH-2019-0031",
  admin: "ADM-2020-0001",
  driver: "DRV-2024-0012",
};

const wantDemo = () => config.seedDemoData || config.demoMode;
const YEAR = "year-2026";

const users = [
  // The demo accounts on the login page.
  {
    id: "STU-2026-0142",
    institution: NOOR,
    role: "student",
    name: "Zainab Haider",
    email: "zainab.haider@school.edu",
    phone: "+964 770 123 4567",
    className: "5th Scientific – A",
  },
  {
    // Zainab's younger brother, at the intermediate school.
    id: "STU-2026-0388",
    institution: NOOR_INTERMEDIATE,
    role: "student",
    name: "Ali Haider",
    email: "ali.haider@school.edu",
    phone: "+964 770 123 4567",
    className: "2nd Intermediate – B",
  },
  {
    id: "TCH-2019-0031",
    institution: NOOR,
    role: "teacher",
    name: "Ahmed Kareem",
    email: "ahmed.kareem@school.edu",
    phone: "+964 780 555 0131",
    subjectName: "Mathematics",
  },
  {
    id: "PAR-2026-0142",
    institution: NOOR,
    role: "parent",
    name: "Haider Jasim",
    email: "haider.jasim@gmail.com",
    phone: "+964 770 123 4567",
  },
  {
    id: "ADM-2020-0001",
    institution: NOOR,
    role: "admin",
    name: "Salma Hashim",
    email: "admin@alnoor.edu.iq",
    phone: "+964 790 222 1100",
  },
  {
    id: "DRV-2024-0012",
    institution: NOOR,
    role: "driver",
    name: "Kadhim Jawad",
    email: "",
    phone: "+964 770 900 1212",
  },
];

// The rest of the People directory (same IDs as the app's mock data).
const SCHOOL_STUDENTS = [
  ["STU-2026-0150", "Fatima Ali", "5th Scientific – A"],
  ["STU-2026-0151", "Maryam Hussein", "5th Scientific – A"],
  ["STU-2026-0152", "Noor Abbas", "5th Scientific – A"],
  ["STU-2026-0153", "Ali Hassan", "5th Scientific – B"],
  ["STU-2026-0154", "Mustafa Kareem", "5th Scientific – B"],
  ["STU-2026-0155", "Hussein Adel", "4th Scientific – A"],
  ["STU-2026-0156", "Yousif Raad", "4th Scientific – A"],
  ["STU-2026-0157", "Sara Mahdi", "6th Scientific – C"],
  ["STU-2026-0158", "Hawraa Kadhim", "6th Scientific – C"],
  ["STU-2026-0159", "Duaa Saad", "4th Scientific – A"],
  ["STU-2026-0160", "Ruqaya Salman", "4th Scientific – A"],
  ["STU-2026-0161", "Zahraa Jaafar", "5th Scientific – B"],
  ["STU-2026-0162", "Aya Ahmed", "5th Scientific – B"],
  ["STU-2026-0163", "Abbas Naji", "5th Scientific – A"],
  ["STU-2026-0164", "Rusul Hadi", "6th Scientific – C"],
  ["STU-2026-0165", "Tabarak Qasim", "4th Scientific – A"],
];
for (const [id, name, className] of SCHOOL_STUDENTS) {
  users.push({
    id,
    institution: NOOR,
    role: "student",
    name,
    email: `${name.toLowerCase().replace(/ /g, ".")}@school.edu`,
    phone: "",
    className,
    // One account not activated yet, so the screens show that state.
    isActive: id !== "STU-2026-0154",
  });
}

const TEACHERS = [
  ["TCH-2019-0040", "Sara Hadi", "Physics"],
  ["TCH-2019-0041", "Omar Saleh", "Chemistry"],
  ["TCH-2019-0042", "Huda Jaber", "Arabic Language"],
  ["TCH-2019-0043", "Rana Sami", "English"],
  ["TCH-2019-0044", "Yusuf Ali", "Islamic Education"],
  ["TCH-2019-0045", "Noor Abbas", "Biology"],
  ["TCH-2019-0046", "Bilal Nasser", "Computer Science"],
];
for (const [id, name, subjectName] of TEACHERS) {
  users.push({
    id,
    institution: NOOR,
    role: "teacher",
    name,
    email: `${name.split(" ")[0].toLowerCase()}@school.edu`,
    phone: "",
    subjectName,
  });
}

for (const [id, name, phone] of [
  ["PAR-2026-0150", "Ali Hassan Sr.", "+964 771 400 2211"],
  ["PAR-2026-0151", "Kareem Mahmoud", "+964 780 300 9090"],
  ["PAR-2026-0152", "Mahdi Saleh", "+964 750 111 7788"],
]) {
  users.push({ id, institution: NOOR, role: "parent", name, email: "", phone });
}

for (const [id, name, phone] of [
  ["DRV-2024-0019", "Salam Hameed", "+964 780 222 7070"],
  ["DRV-2025-0027", "Abbas Fadhil", "+964 771 640 3030"],
]) {
  users.push({ id, institution: NOOR, role: "driver", name, email: "", phone });
}

// The school's own breaks. Official holidays come from
// features/institution/official-holidays.js.
const holidays = [
  ["Mid-year break", "schoolBreak", "2027-01-24", "2027-02-04"],
];

// [title, type, audience, date, time, place, details]
const events = [
  ["Sports day", "event", "everyone", "2026-10-29", "09:00", "School playground", ""],
  ["Class photo day", "event", "everyone", "2026-11-05", "08:30", "", "Wear the full uniform"],
  ["Mathematics department meeting", "meeting", "staff", "2026-11-09", "13:30", "Staff room", ""],
  ["Parent–teacher meeting", "meeting", "families", "2026-11-12", "14:00", "Main hall", "2:00 – 5:00 pm, by class"],
  ["Science fair", "event", "everyone", "2026-11-15", "09:00", "School courtyard", ""],
  ["Trip to the Iraq Natural History Museum", "event", "everyone", "2026-11-24", "08:00", "", "Bring the signed permission slip"],
];

// [id, name, icon, color, teacher]
const SUBJECTS = [
  ["math", "Mathematics", "math", "purple", "TCH-2019-0031"],
  ["physics", "Physics", "physics", "blue", "TCH-2019-0040"],
  ["chemistry", "Chemistry", "chemistry", "teal", "TCH-2019-0041"],
  ["arabic", "Arabic Language", "language", "orange", "TCH-2019-0042"],
  ["english", "English", "english", "pink", "TCH-2019-0043"],
  ["islamic", "Islamic Education", "islamic", "amber", "TCH-2019-0044"],
  ["biology", "Biology", "biology", "green", "TCH-2019-0045"],
  ["computer", "Computer Science", "computer", "gray", "TCH-2019-0046"],
];

// [id, name, head teacher, subjects still without a teacher]
const CLASSES = [
  ["cls-4a", "4th Scientific – A", "TCH-2019-0041", []],
  ["cls-5a", "5th Scientific – A", "TCH-2019-0042", []],
  // A class still being set up.
  ["cls-5b", "5th Scientific – B", "TCH-2019-0044", ["biology", "computer"]],
  ["cls-6c", "6th Scientific – C", "TCH-2019-0040", []],
];

/**
 * Subjects and classes for the demo school. Runs whenever the school has
 * none yet, so it also fills databases created before this table existed.
 */
async function seedAcademics() {
  if (!wantDemo()) return false;
  if (!(await queryOne("SELECT id FROM institutions WHERE id = $1", [NOOR]))) {
    return false;
  }
  if (await queryOne("SELECT id FROM subjects WHERE institution_id = $1 LIMIT 1", [NOOR])) {
    return false;
  }

  await transaction(async (tx) => {
    for (const [id, name, icon, color] of SUBJECTS) {
      await tx.query(
        `INSERT INTO subjects (id, institution_id, name, icon, color)
         VALUES ($1, $2, $3, $4, $5)`,
        [id, NOOR, name, icon, color],
      );
    }
    for (const [id, name, homeroom, unassigned] of CLASSES) {
      await tx.query(
        `INSERT INTO classes (id, institution_id, name, homeroom_teacher_id)
         VALUES ($1, $2, $3, $4)`,
        [id, NOOR, name, homeroom],
      );
      for (const [subjectId, , , , teacher] of SUBJECTS) {
        await tx.query(
          `INSERT INTO class_subjects (class_id, subject_id, teacher_id)
           VALUES ($1, $2, $3)`,
          [id, subjectId, unassigned.includes(subjectId) ? null : teacher],
        );
      }
    }
  });

  return true;
}

// [title, body, audience, class id, author id, author name, hours ago, pinned]
const ANNOUNCEMENTS = [
  [
    "Mid-term exams timetable published",
    "The mid-term exam timetable is now available in the Exams section. Exams start on the 16th and run for two weeks. Please arrive 15 minutes early and bring your student card.\n\nIf you have two exams on the same day, contact the exams office.",
    "school", null, "ADM-2020-0001", "Exams Office", 3, true,
  ],
  [
    "Chemistry lab moved to Thursday",
    "This week's chemistry lab session is moved from Wednesday to Thursday, same time. Lab coats are required.",
    "class", "cls-5a", "TCH-2019-0041", "Mr. Omar Saleh", 20, false,
  ],
  [
    "Parent–teacher meeting",
    "Parents are invited to meet teachers next Monday from 2:00 pm to 5:00 pm in the main hall. Booking a time slot is not required.",
    "parents", null, "ADM-2020-0001", "School Administration", 48, false,
  ],
  [
    "Library opening hours extended",
    "During the exam period the library will stay open until 6:00 pm from Sunday to Thursday.",
    "school", null, "ADM-2020-0001", "Library", 96, false,
  ],
  [
    "Class photo day",
    "Class photos will be taken on Tuesday morning. Please wear the full school uniform.",
    "class", "cls-5a", "TCH-2019-0042", "Ms. Huda Jaber", 144, false,
  ],
];

/** The demo notice board. Runs whenever the school has no announcements yet. */
async function seedAnnouncements() {
  if (!wantDemo()) return false;
  if (!(await queryOne("SELECT id FROM classes WHERE id = 'cls-5a'"))) return false;
  if (await queryOne("SELECT id FROM announcements WHERE institution_id = $1 LIMIT 1", [NOOR])) {
    return false;
  }

  await transaction(async (tx) => {
    for (const [title, body, audience, classId, authorId, authorName, hoursAgo, pinned] of ANNOUNCEMENTS) {
      await tx.query(
        `INSERT INTO announcements (institution_id, title, body, audience, class_id,
                                    author_id, author_name, published_at, is_pinned,
                                    notified)
         VALUES ($1, $2, $3, $4, $5, $6, $7, now() - make_interval(hours => $8), $9, true)`,
        [NOOR, title, body, audience, classId, authorId, authorName, hoursAgo, pinned],
      );
    }
  });

  return true;
}

// [id, name, bus, plate, driver, supervisor, supervisor phone, school times,
//  stops: [id, name, landmark, lat, lng, morning, afternoon],
//  riders: [student, stop]]
const BUS_LINES = [
  [
    "route-1", "Al-Mansour line", "12", "Baghdad 41582", "DRV-2024-0012",
    "Ms. Iman Fadhil", "+964 771 300 4545", [465, 800],
    [
      ["s1", "Al-Ghazaliya", "Al-Ghazaliya square", 33.338, 44.27, 410, 854],
      ["s2", "Al-Adel", "Al-Adel mosque", 33.33, 44.3, 422, 842],
      ["s3", "Hay Al-Jamia", "Al-Jamia street", 33.317, 44.318, 432, 832],
      ["s4", "Al-Yarmouk", "Al-Yarmouk hospital", 33.3, 44.335, 442, 822],
      ["s5", "Al-Mansour", "14th of Ramadan street", 33.31, 44.35, 452, 812],
    ],
    [
      ["STU-2026-0142", "s4"], ["STU-2026-0150", "s1"], ["STU-2026-0151", "s1"],
      ["STU-2026-0152", "s2"], ["STU-2026-0159", "s2"], ["STU-2026-0157", "s3"],
      ["STU-2026-0158", "s3"], ["STU-2026-0160", "s4"], ["STU-2026-0161", "s5"],
      ["STU-2026-0162", "s5"],
    ],
  ],
  [
    "route-2", "Al-Karrada line", "7", "Baghdad 30917", "DRV-2024-0019",
    "Ms. Rasha Kamil", "+964 772 555 1919", [465, 800],
    [
      ["k1", "Al-Karrada", "Kahramana square", 33.3, 44.42, 420, 840],
      ["k2", "Al-Jadriya", "Al-Jadriya bridge", 33.28, 44.38, 440, 820],
    ],
    [
      ["STU-2026-0153", "k1"], ["STU-2026-0154", "k1"],
      ["STU-2026-0155", "k2"], ["STU-2026-0156", "k2"],
    ],
  ],
];

// 5th A's week, the same as the app's mock timetable. Days: 7 = Sunday,
// 1 = Monday... Each entry is [subject, room] for period 1, 2, 3...
const WEEK_5A = {
  7: [["islamic", "Room 204"], ["math", "Room 204"], ["physics", "Lab 2"],
      ["arabic", "Room 204"], ["english", "Room 110"], ["biology", "Lab 3"]],
  1: [["chemistry", "Lab 1"], ["math", "Room 204"], ["computer", "Computer Lab"],
      ["arabic", "Room 204"], ["english", "Room 110"], ["physics", "Lab 2"]],
  2: [["english", "Room 110"], ["math", "Room 204"], ["biology", "Lab 3"],
      ["chemistry", "Lab 1"], ["arabic", "Room 204"]],
  3: [["physics", "Lab 2"], ["computer", "Computer Lab"], ["math", "Room 204"],
      ["english", "Room 110"], ["chemistry", "Lab 1"], ["arabic", "Room 204"]],
  4: [["arabic", "Room 204"], ["islamic", "Room 204"], ["math", "Room 204"],
      ["computer", "Computer Lab"]],
};

// Mr. Ahmed Kareem's maths in the other classes, as in the app's mock
// teacher timetable: [class, day, period].
const MATHS_ELSEWHERE = [
  ["cls-5b", 7, 3], ["cls-4a", 7, 5],
  ["cls-6c", 1, 1], ["cls-5b", 1, 4],
  ["cls-4a", 2, 1], ["cls-6c", 2, 3], ["cls-5b", 2, 5],
  ["cls-5b", 3, 1], ["cls-6c", 3, 4], ["cls-4a", 3, 5],
  ["cls-6c", 4, 2],
];

const HOME_ROOMS = { "cls-4a": "Room 105", "cls-5b": "Room 206", "cls-6c": "Room 301" };

/**
 * The demo timetable: 5th A as in the app, the other classes filled so that
 * no teacher is in two classes at once. Runs while no class has lessons.
 */
async function seedTimetable() {
  if (!wantDemo()) return false;
  if (!(await queryOne("SELECT id FROM classes WHERE id = 'cls-5a'"))) return false;
  if (await queryOne("SELECT class_id FROM timetable_slots WHERE class_id = 'cls-5a' LIMIT 1")) return false;

  const teacherOf = Object.fromEntries(SUBJECTS.map(([id, , , , t]) => [id, t]));
  const busy = new Set(); // "teacher/day/period"
  const lessons = []; // [class, day, period, subject, room]
  const place = (classId, day, period, subject, room) => {
    busy.add(`${teacherOf[subject]}/${day}/${period}`);
    lessons.push([classId, day, period, subject, room]);
  };

  for (const [day, periods] of Object.entries(WEEK_5A)) {
    periods.forEach(([subject, room], i) => place("cls-5a", Number(day), i + 1, subject, room));
  }
  for (const [classId, day, period] of MATHS_ELSEWHERE) {
    place(classId, day, period, "math", HOME_ROOMS[classId]);
  }

  // Fill the rest of each class's day with a free teacher, at most two
  // lessons of a subject per day.
  const others = SUBJECTS.map(([id]) => id).filter((id) => id !== "math");
  for (const [c, classId] of Object.keys(HOME_ROOMS).entries()) {
    for (const [day, periods] of Object.entries(WEEK_5A)) {
      for (let period = 1; period <= periods.length; period++) {
        const taken = lessons.filter(([k, d]) => k === classId && d === Number(day));
        if (taken.some(([, , p]) => p === period)) continue;
        for (let k = 0; k < others.length; k++) {
          const subject = others[(c * 3 + Number(day) + period + k) % others.length];
          const free = !busy.has(`${teacherOf[subject]}/${day}/${period}`);
          const times = taken.filter(([, , , s]) => s === subject).length;
          if (free && times < 2) {
            place(classId, Number(day), period, subject, HOME_ROOMS[classId]);
            break;
          }
        }
      }
    }
  }

  await transaction(async (tx) => {
    for (const lesson of lessons) {
      await tx.query(
        `INSERT INTO timetable_slots (class_id, weekday, period, subject_id, room)
         VALUES ($1, $2, $3, $4, $5)`,
        lesson,
      );
    }
  });
  return true;
}

// Zainab's days that weren't a plain "present", as in the app's mock data:
// days ago → [status, which periods ("all" or a list)] or an excuse note.
const ZAINAB_DAYS = {
  2: ["late", [1]],
  9: ["absent", "all"],
  15: { excused: "Medical note received" },
  16: { excused: "Medical note received" },
  23: ["late", [1]],
};
// Fatima missed one lesson 5 days ago.
const FATIMA_DAYS = { 5: ["absent", [3]] };

/**
 * Demo attendance for 5th A: every lesson of the last 30 days is marked,
 * almost everyone present. Runs while there are no marks at all.
 */
async function seedAttendance() {
  if (!wantDemo()) return false;
  const attendance = require("../features/attendance/attendance.repository");
  const timetable = require("../features/timetable/timetable.repository");
  const { today, addDays, weekdayOf, schoolCalendar } = require("../features/attendance/school-days");
  if (await queryOne("SELECT 1 AS yes FROM attendance_marks WHERE class_id = 'cls-5a' LIMIT 1")) return false;
  const calendar = await schoolCalendar(NOOR);
  const week = await timetable.classWeek("cls-5a");
  if (!calendar || week.length === 0) return false;

  const students = await attendance.classStudents("cls-5a");
  const exceptions = { "STU-2026-0142": ZAINAB_DAYS, "STU-2026-0150": FATIMA_DAYS };
  const now = today();

  await transaction(async (tx) => {
    for (let daysAgo = 1; daysAgo <= 30; daysAgo++) {
      const date = addDays(now, -daysAgo);
      if (!calendar.isSchoolDay(date)) continue;

      for (const lesson of week.filter((l) => l.weekday === weekdayOf(date))) {
        const marks = {};
        for (const { id } of students) {
          const special = exceptions[id]?.[daysAgo];
          const [status, periods] = Array.isArray(special) ? special : [];
          const hit = periods === "all" || periods?.includes(lesson.period);
          marks[id] = hit ? status : special?.excused ? "absent" : "present";
        }
        await attendance.saveLessonMarks(
          tx,
          {
            classId: "cls-5a",
            date,
            period: lesson.period,
            subjectName: lesson.subjectName,
            markedBy: lesson.teacherId,
          },
          marks,
        );
        // Taken 5 minutes into the lesson, on the school's clock.
        await tx.query(
          `UPDATE attendance_marks
           SET marked_at = (($2::date + $3::time) + interval '5 minutes') AT TIME ZONE $5
           WHERE class_id = 'cls-5a' AND date = $2 AND period = $4 AND marked_by = $1`,
          [lesson.teacherId, date, lesson.start, lesson.period, config.timeZone],
        );
      }
      for (const [id, days] of Object.entries(exceptions)) {
        if (days[daysAgo]?.excused) {
          await tx.query(
            `INSERT INTO attendance_excuses (student_id, date, note, created_by)
             VALUES ($1, $2, $3, 'ADM-2020-0001')`,
            [id, date, days[daysAgo].excused],
          );
        }
      }
    }
  });
  return true;
}

// 5th A's exams, as in the app's mock grades and exams.
// [subject, type, title, days from today, max, Zainab's score, time, minutes, room, topics]
const EXAMS_5A = [
  ["math", "quiz", "Algebra quiz", -20, 10, 9],
  ["math", "monthly", "Functions test", -12, 50, 42],
  ["math", "quiz", "Worksheet 3", -5, 10, 10],
  ["physics", "quiz", "Motion quiz", -18, 10, 7],
  ["physics", "quiz", "Forces lab", -9, 20, 16],
  ["chemistry", "quiz", "Periodic table quiz", -15, 10, 8],
  ["chemistry", "monthly", "Bonding test", -7, 50, 31],
  ["arabic", "quiz", "Grammar quiz", -14, 20, 18],
  ["arabic", "monthly", "Poetry analysis", -5, 50, 41],
  ["english", "monthly", "Reading test", -10, 50, 45],
  ["english", "quiz", "Vocabulary quiz", -3, 20, 19],
  ["islamic", "quiz", "Surat Al-Hujurat summary", -7, 20, 18],
  ["computer", "quiz", "Spreadsheet basics", -16, 10, 10],
  ["english", "quiz", "Unit 4 vocabulary", 2, 20, null, "10:45", 30, "Room 110", ["Unit 4 vocabulary"]],
  ["math", "monthly", "November monthly exam", 5, 100, null, "08:00", 90, "Hall A",
    ["Quadratic equations", "Functions", "Inequalities"]],
  ["physics", "monthly", "November monthly exam", 7, 100, null, "08:00", 90, "Hall A",
    ["Motion", "Newton's laws", "Forces"]],
  ["chemistry", "monthly", "November monthly exam", 9, 100, null, "08:00", 90, "Hall B",
    ["Periodic table", "Chemical bonding"]],
  ["arabic", "monthly", "November monthly exam", 12, 100, null, "08:00", 90, "Hall A", []],
];

/**
 * Demo exams for 5th A: past ones with published scores (Zainab's as in the
 * app, the others varied), upcoming ones without. Runs while there are none.
 */
async function seedExams() {
  if (!wantDemo()) return false;
  const exams = require("../features/exams/exams.repository");
  const attendance = require("../features/attendance/attendance.repository");
  const { today, addDays, schoolCalendar } = require("../features/attendance/school-days");
  if (await queryOne("SELECT id FROM exams WHERE class_id = 'cls-5a' LIMIT 1")) return false;
  const calendar = await schoolCalendar(NOOR);
  if (!calendar || !(await queryOne("SELECT id FROM classes WHERE id = 'cls-5a'"))) {
    return false;
  }

  const students = await attendance.classStudents("cls-5a");
  const now = today();
  /** The school day [offset] days away, moving away from today until one is found. */
  const schoolDay = (offset) => {
    const step = offset < 0 ? -1 : 1;
    for (let d = offset; Math.abs(d) < Math.abs(offset) + 10; d += step) {
      const date = addDays(now, d);
      if (calendar.isSchoolDay(date)) return date;
    }
    return null;
  };

  await transaction(async (tx) => {
    for (const [i, row] of EXAMS_5A.entries()) {
      const [subjectId, type, title, offset, maxScore, zainab, time, minutes, room, topics] = row;
      const date = schoolDay(offset);
      if (!date) continue;

      const { id } = await tx.queryOne(
        `INSERT INTO exams (institution_id, class_id, subject_id, type, title, date,
                            start_time, duration_minutes, room, topics, max_score,
                            published_at, created_by)
         VALUES ($1, 'cls-5a', $2, $3, $4, $5, $6, $7, $8, $9, $10,
                 -- Scores published the day after the exam, after school.
                 CASE WHEN $11 THEN ($5::date + interval '1 day 13 hours') AT TIME ZONE 'Asia/Baghdad' END,
                 (SELECT teacher_id FROM class_subjects
                  WHERE class_id = 'cls-5a' AND subject_id = $2))
         RETURNING id`,
        [NOOR, subjectId, type, title, date, time ?? "08:00", minutes ?? 45,
         room ?? "", topics ?? [], maxScore, zainab !== null],
      );
      if (zainab === null) continue;

      for (const [k, student] of students.entries()) {
        // Zainab as in the app; the others between 45% and 100%, repeatably.
        const score = student.id === "STU-2026-0142"
          ? zainab
          : Math.round(maxScore * (45 + ((k * 37 + i * 11) % 56)) / 100);
        await tx.query(
          "INSERT INTO exam_scores (exam_id, student_id, score) VALUES ($1, $2, $3)",
          [id, student.id, score],
        );
      }
    }
  });
  return true;
}

// 5th A's homework, as in the app's mock data.
// [subject, type, title, description, assigned (days, hour), due (days, hour, min),
//  allows late, max grade, Zainab: null | "submitted" | [grade, feedback]]
const ASSIGNMENTS_5A = [
  ["math", "homework", "Quadratic equations – worksheet 4",
    "Solve questions 1 to 12 on the worksheet. Show every step of your work; final answers alone will not get full marks.",
    [-3, 9], [1, 23, 59], false, 10, null],
  ["chemistry", "assignment", "Lab report: rates of reaction",
    "Write up the experiment from Monday's lab. Include your hypothesis, method, results table, a graph and a short conclusion.",
    [-5, 10], [3, 23, 59], true, 20, null],
  ["english", "assignment", "Essay: a place I remember",
    "Write 300–400 words about a place that matters to you. Use at least five of this unit's descriptive adjectives.",
    [-8, 11], [-1, 23, 59], true, 20, null],
  ["physics", "quiz", "Newton's laws quiz",
    "Ten questions on the three laws. Answer on the sheet handed out in class.",
    [-2, 8], [5, 9, 40], false, 10, null],
  ["computer", "project", "Build a simple calculator",
    "Make a calculator that adds, subtracts, multiplies and divides two numbers. Hand in your project file.",
    [-10, 12], [-2, 23, 59], false, 20, "submitted"],
  ["islamic", "homework", "Surat Al-Hujurat – lesson summary",
    "Summarise the lessons of verses 10–13 in your own words.",
    [-14, 9], [-7, 23, 59], false, 20, [18, "Clear and well organised. Add one more example next time."]],
  ["arabic", "assignment", "Poetry analysis",
    "Analyse the imagery of the poem from lesson 7.",
    [-12, 9], [-5, 23, 59], false, 50, [41, "Good understanding of the imagery. Watch your spelling."]],
];

/** Demo homework for 5th A. Runs while there is none. */
async function seedAssignments() {
  if (!wantDemo()) return false;
  const assignments = require("../features/assignments/assignments.repository");
  if (await queryOne("SELECT id FROM assignments WHERE class_id = 'cls-5a' LIMIT 1")) return false;
  if (!(await queryOne("SELECT id FROM classes WHERE id = 'cls-5a'"))) return false;

  const at = (days, hour, minute = 0) => {
    const d = new Date();
    d.setDate(d.getDate() + days);
    d.setHours(hour, minute, 0, 0);
    return d;
  };

  await transaction(async (tx) => {
    for (const [subject, type, title, description, assigned, due, late, max, zainab] of ASSIGNMENTS_5A) {
      const { id } = await tx.queryOne(
        `INSERT INTO assignments (institution_id, class_id, subject_id, type, title, description,
           assigned_at, due_at, allows_late, accepts_files, max_grade, created_by)
         VALUES ($1, 'cls-5a', $2, $3, $4, $5, $6, $7, $8, false, $9,
           (SELECT teacher_id FROM class_subjects WHERE class_id = 'cls-5a' AND subject_id = $2))
         RETURNING id`,
        [NOOR, subject, type, title, description, at(...assigned), at(...due), late, max],
      );
      if (zainab) {
        const [grade, feedback] = Array.isArray(zainab) ? zainab : [null, null];
        await tx.query(
          `INSERT INTO submissions (assignment_id, student_id, submitted_at, grade, feedback, graded_at)
           VALUES ($1, 'STU-2026-0142', $2, $3, $4, CASE WHEN $3::numeric IS NULL THEN NULL ELSE $5::timestamptz END)`,
          // Graded two days after the due date.
          [id, at(due[0] - 1, 20), grade, feedback, at(due[0] + 2, 16)],
        );
      }
      // Two classmates already handed in the maths worksheet.
      if (subject === "math") {
        for (const student of ["STU-2026-0150", "STU-2026-0151"]) {
          await tx.query(
            "INSERT INTO submissions (assignment_id, student_id, submitted_at) VALUES ($1, $2, now())",
            [id, student],
          );
        }
      }
    }
  });
  return true;
}

// Demo chats: [between (or a class), [[sender, text, minutes ago]...]]
const CHATS = [
  [["STU-2026-0142", "TCH-2019-0031"], [
    ["STU-2026-0142", "Sir, is question 7 on the worksheet about the discriminant?", 190],
    ["TCH-2019-0031", "Yes. Find b² − 4ac first, then decide how many roots there are.", 175],
    ["STU-2026-0142", "Thank you!", 170],
  ]],
  [["PAR-2026-0142", "TCH-2019-0042"], [
    ["PAR-2026-0142", "Good evening, Ms. Huda. How is Zainab doing in Arabic this month?", 1500],
    ["TCH-2019-0042", "Very well. Her poetry analysis was one of the best in the class.", 1440],
  ]],
  ["cls-5a", [
    ["TCH-2019-0041", "Reminder: lab coats for Thursday's chemistry lab.", 300],
    ["STU-2026-0150", "Will the lab report be due next week?", 290],
    ["TCH-2019-0041", "Yes, three days after the lab.", 280],
  ]],
];

/** Demo chats. Runs while there are no messages. */
async function seedMessages() {
  if (!wantDemo()) return false;
  const messages = require("../features/messages/messages.repository");
  if (await queryOne("SELECT id FROM conversations WHERE institution_id = $1 LIMIT 1", [NOOR])) return false;
  if (!(await queryOne("SELECT id FROM classes WHERE id = 'cls-5a'"))) return false;

  await transaction(async (tx) => {
    for (const [between, lines] of CHATS) {
      let id;
      if (Array.isArray(between)) {
        id = await messages.directConversation(tx, NOOR, ...between);
      } else {
        const row = await tx.queryOne(
          `INSERT INTO conversations (institution_id, kind, class_id) VALUES ($1, 'class', $2)
           ON CONFLICT (class_id) DO UPDATE SET class_id = EXCLUDED.class_id RETURNING id`,
          [NOOR, between],
        );
        id = row.id;
      }
      for (const [sender, text, minutesAgo] of lines) {
        await tx.query(
          `INSERT INTO messages (conversation_id, sender_id, text, sent_at)
           VALUES ($1, $2, $3, now() - make_interval(mins => $4))`,
          [id, sender, text, minutesAgo],
        );
      }
    }
  });
  return true;
}

/** Demo fees for 2026–2027, as in the app's mock data: tuition by stage, three installments, sibling discounts, and a mix of families who paid in full, paid the first installment, paid part, or nothing yet. */
async function seedFinance() {
  if (!wantDemo()) return false;
  const finance = require("../features/finance/finance.repository");
  const fees = require("../features/finance/fees");
  if (await queryOne("SELECT id FROM payments WHERE institution_id = $1 LIMIT 1", [NOOR])) return false;
  if (!(await queryOne("SELECT id FROM classes WHERE id = 'cls-5a'"))) return false;

  const dueDates = ["2026-10-01", "2027-01-01", "2027-04-01"];
  await transaction(async (tx) => {
    await finance.saveSettings(tx, NOOR, {
      tuition: 2000000,
      busFee: 600000,
      dueDates,
      classTuition: { "cls-4a": 2000000, "cls-5a": 2250000, "cls-5b": 2250000, "cls-6c": 2500000 },
    });
    await finance.saveSettings(tx, NOOR_INTERMEDIATE, {
      tuition: 1750000, busFee: 600000, dueDates, classTuition: {},
    });
  });
  for (const [id, percent, reason] of [
    ["STU-2026-0142", 10, "Siblings at the school"],
    ["STU-2026-0388", 10, "Siblings at the school"],
    ["STU-2026-0163", 25, "Top of his class"],
  ]) {
    await finance.setDiscount(id, { percent, reason });
  }

  for (const school of [NOOR, NOOR_INTERMEDIATE]) {
    const accounts = await finance.accounts(school);
    await transaction(async (tx) => {
      for (const [i, account] of accounts.entries()) {
        // Zainab paid her first installment; her brother is behind.
        const pattern = account.studentId === "STU-2026-0142" ? 1
          : account.studentId === "STU-2026-0388" ? 3
          : i % 5;
        const first = fees.installmentsOf(account)[0].amount;
        const paid = {
          0: [[fees.totalOf(account), "2026-09-21", "bankTransfer"]],
          1: [[first, "2026-09-28", "cash"]],
          3: [[Math.floor(first / 2000) * 1000, "2026-10-12", "cash"]],
          4: [[first, "2026-09-30", "card"], [500000, "2026-11-02", "eWallet"]],
        }[pattern] ?? [];

        for (const [amount, date, method] of paid) {
          const p = await finance.insertPayment(
            tx, school, account.studentId, { amount, method, note: "" }, "ADM-2020-0001",
          );
          await tx.query("UPDATE payments SET paid_at = $2 WHERE id = $1", [p.id, `${date}T09:00:00`]);
        }
      }
    });
  }
  return true;
}

// 5th A's study material: links (files need a real upload).
// [subject, title, type, url, days ago]
const RESOURCES_5A = [
  ["math", "Solving quadratic equations", "video", "https://www.khanacademy.org/math/algebra/x2f8bb11595b61c86:quadratic-functions-equations", 2],
  ["physics", "Forces simulation (PhET)", "link", "https://phet.colorado.edu/en/simulations/forces-and-motion-basics", 4],
  ["chemistry", "Chemical bonding explained", "video", "https://www.khanacademy.org/science/chemistry/chemical-bonds", 6],
  ["english", "Descriptive writing tips", "link", "https://learnenglishteens.britishcouncil.org/skills/writing", 9],
];

// Zainab's own tasks, as in the app: [id, title, note, days, hour, minute, priority, reminder, done]
const ZAINAB_TASKS = [
  ["t1", "Review chapter 3 for the math mid-term", "Focus on functions and inequalities.", 0, 19, 0, "high", false, false],
  ["t2", "Read 20 pages of the English novel", null, 0, 21, 0, "low", true, false],
  ["t3", "Bring lab coat", null, 1, 7, 30, "medium", false, false],
  ["t4", "Make flashcards for chemistry", null, 3, 18, 0, "medium", false, false],
  ["t5", "Return library book", null, -1, 14, 0, "medium", false, true],
  ["t6", "Print Islamic Education summary", null, -2, 20, 0, "medium", false, true],
];

/** Demo study material and Zainab's tasks. Runs while there are none. */
async function seedTasksAndResources() {
  if (!wantDemo()) return false;
  if (await queryOne("SELECT id FROM resources WHERE class_id = 'cls-5a' LIMIT 1")) return false;
  if (!(await queryOne("SELECT id FROM classes WHERE id = 'cls-5a'"))) return false;

  const at = (days, hour, minute = 0) => {
    const d = new Date();
    d.setDate(d.getDate() + days);
    d.setHours(hour, minute, 0, 0);
    return d;
  };

  await transaction(async (tx) => {
    for (const [subject, title, type, url, daysAgo] of RESOURCES_5A) {
      await tx.query(
        `INSERT INTO resources (institution_id, class_id, subject_id, title, type, url, created_by, created_at)
         VALUES ($1, 'cls-5a', $2, $3, $4, $5,
           (SELECT teacher_id FROM class_subjects WHERE class_id = 'cls-5a' AND subject_id = $2), $6)`,
        [NOOR, subject, title, type, url, at(-daysAgo, 10)],
      );
    }
    for (const [id, title, note, days, hour, minute, priority, reminder, done] of ZAINAB_TASKS) {
      await tx.query(
        `INSERT INTO tasks (user_id, id, title, note, due_at, priority, is_reminder, is_done)
         VALUES ('STU-2026-0142', $1, $2, $3, $4, $5, $6, $7) ON CONFLICT DO NOTHING`,
        [id, title, note, at(days, hour, minute), priority, reminder, done],
      );
    }
  });
  return true;
}

/**
 * The demo's history in the activity log (it was made before the log
 * existed): attendance taken, absences, scores, homework, notices and
 * payments. Runs while the log is empty.
 */
async function seedActivityLog() {
  if (!wantDemo()) return false;
  if (await queryOne("SELECT id FROM activity_log WHERE institution_id = $1 LIMIT 1", [NOOR])) return false;
  const tz = config.timeZone;

  await transaction(async (tx) => {
    // A teacher took attendance for a lesson.
    await tx.query(
      `INSERT INTO activity_log (institution_id, at, actor_id, actor_name, actor_role, kind,
                                 action, summary, summary_ar, class_id, route)
       SELECT c.institution_id, MAX(m.marked_at), m.marked_by, u.name, u.role, 'attendance',
              'attendance.taken',
              u.name || ' took attendance for ' || c.name || ', period ' || m.period ||
                ' (' || MAX(m.subject_name) || ') on ' || m.date || ': ' ||
                COUNT(*) FILTER (WHERE m.status = 'present') || ' present, ' ||
                COUNT(*) FILTER (WHERE m.status = 'late') || ' late, ' ||
                COUNT(*) FILTER (WHERE m.status = 'absent') || ' absent',
              'سجّل ' || u.name || ' حضور ' || c.name || '، الحصة ' || m.period ||
                ' (' || MAX(m.subject_name) || ') يوم ' || m.date || ': ' ||
                COUNT(*) FILTER (WHERE m.status = 'present') || ' حاضر، ' ||
                COUNT(*) FILTER (WHERE m.status = 'late') || ' متأخر، ' ||
                COUNT(*) FILTER (WHERE m.status = 'absent') || ' غائب',
              c.id, '/classes/' || c.id || '/attendance'
       FROM attendance_marks m JOIN classes c ON c.id = m.class_id
       JOIN users u ON u.id = m.marked_by
       GROUP BY c.institution_id, c.id, c.name, m.date, m.period, m.marked_by, u.name, u.role`,
    );
    // Each late or absent mark, for that student and their parents.
    await tx.query(
      `INSERT INTO activity_log (institution_id, at, actor_id, actor_name, actor_role, kind,
                                 action, summary, summary_ar, class_id, student_ids, route)
       SELECT c.institution_id, m.marked_at, m.marked_by, u.name, u.role, 'attendance',
              'attendance.marked',
              u.name || ' marked ' || s.name || ' ' || m.status || ' in ' || m.subject_name ||
                ' (period ' || m.period || ', ' || m.date || ')',
              'سجّل ' || u.name || ' ' || s.name || ': ' ||
                CASE m.status WHEN 'absent' THEN 'غائب' ELSE 'متأخر' END ||
                ' في ' || m.subject_name || ' (الحصة ' || m.period || '، ' || m.date || ')',
              c.id, ARRAY[m.student_id], '/attendance'
       FROM attendance_marks m JOIN classes c ON c.id = m.class_id
       JOIN users u ON u.id = m.marked_by JOIN users s ON s.id = m.student_id
       WHERE m.status <> 'present'`,
    );
    // Scores published.
    await tx.query(
      `INSERT INTO activity_log (institution_id, at, actor_id, actor_name, actor_role, kind,
                                 action, summary, summary_ar, class_id, route)
       SELECT e.institution_id, e.published_at, e.created_by, u.name, u.role, 'grades', 'exam.scored',
              u.name || ' published ' || e.title || ' scores (' || s.name || ') for ' || c.name,
              'نشر ' || u.name || ' درجات ' || e.title || ' (' || s.name || ') لـ ' || c.name,
              c.id, '/grades'
       FROM exams e JOIN classes c ON c.id = e.class_id JOIN subjects s ON s.id = e.subject_id
       JOIN users u ON u.id = e.created_by
       WHERE e.published_at IS NOT NULL`,
    );
    // Homework set, handed in and graded.
    await tx.query(
      `INSERT INTO activity_log (institution_id, at, actor_id, actor_name, actor_role, kind,
                                 action, summary, summary_ar, class_id, route)
       SELECT a.institution_id, a.assigned_at, a.created_by, u.name, u.role, 'homework', 'homework.set',
              u.name || ' set "' || a.title || '" (' || s.name || ') for ' || c.name,
              'أضاف ' || u.name || ' واجب "' || a.title || '" (' || s.name || ') لـ ' || c.name,
              c.id, '/assignments/' || a.id
       FROM assignments a JOIN classes c ON c.id = a.class_id JOIN subjects s ON s.id = a.subject_id
       JOIN users u ON u.id = a.created_by`,
    );
    await tx.query(
      `INSERT INTO activity_log (institution_id, at, actor_id, actor_name, actor_role, kind,
                                 action, summary, summary_ar, class_id, student_ids, route)
       SELECT a.institution_id, sb.submitted_at, st.id, st.name, 'student', 'homework', 'homework.handedIn',
              st.name || ' handed in "' || a.title || '" (' || s.name || ')',
              'سلّم ' || st.name || ' "' || a.title || '" (' || s.name || ')',
              a.class_id, ARRAY[st.id], '/assignments/' || a.id
       FROM submissions sb JOIN assignments a ON a.id = sb.assignment_id
       JOIN subjects s ON s.id = a.subject_id JOIN users st ON st.id = sb.student_id
       WHERE sb.submitted_at IS NOT NULL`,
    );
    await tx.query(
      `INSERT INTO activity_log (institution_id, at, actor_id, actor_name, actor_role, kind,
                                 action, summary, summary_ar, class_id, student_ids, route)
       SELECT a.institution_id, sb.graded_at, u.id, u.name, u.role, 'homework', 'homework.graded',
              u.name || ' graded ' || st.name || chr(39) || 's "' || a.title || '": ' ||
                trim_scale(sb.grade) || ' / ' || trim_scale(a.max_grade),
              'صحّح ' || u.name || ' "' || a.title || '" لـ ' || st.name || ': ' ||
                trim_scale(sb.grade) || ' / ' || trim_scale(a.max_grade),
              a.class_id, ARRAY[st.id], '/assignments/' || a.id
       FROM submissions sb JOIN assignments a ON a.id = sb.assignment_id
       JOIN users st ON st.id = sb.student_id JOIN users u ON u.id = a.created_by
       WHERE sb.grade IS NOT NULL`,
    );
    // Notices and payments.
    await tx.query(
      `INSERT INTO activity_log (institution_id, at, actor_id, actor_name, actor_role, kind,
                                 action, summary, summary_ar, class_id, route)
       SELECT n.institution_id, n.published_at, n.author_id, n.author_name, COALESCE(u.role, 'admin'),
              'announcement', 'announcement.posted',
              n.author_name || ' posted "' || n.title || '"',
              'نشر ' || n.author_name || ' "' || n.title || '"',
              n.class_id, '/announcements/' || n.id
       FROM announcements n LEFT JOIN users u ON u.id = n.author_id
       WHERE n.published_at <= now()`,
    );
    await tx.query(
      `INSERT INTO activity_log (institution_id, at, actor_id, actor_name, actor_role, kind,
                                 action, summary, summary_ar, student_ids, route)
       SELECT p.institution_id, p.paid_at, p.recorded_by, u.name, u.role, 'finance', 'payment.recorded',
              u.name || ' recorded ' || to_char(p.amount, 'FM999,999,999') || ' IQD for ' ||
                s.name || ' (' || p.receipt_number || ')',
              'سجّل ' || u.name || ' ' || to_char(p.amount, 'FM999,999,999') || ' د.ع لـ ' ||
                s.name || ' (' || p.receipt_number || ')',
              ARRAY[p.student_id], '/finance/' || p.student_id
       FROM payments p JOIN users u ON u.id = p.recorded_by JOIN users s ON s.id = p.student_id
       WHERE p.voided_at IS NULL`,
    );
  });
  return true;
}

/** The demo bus lines. Runs whenever the school has no bus lines yet. */
async function seedTransport() {
  if (!wantDemo()) return false;
  if (!(await queryOne("SELECT id FROM users WHERE id = 'DRV-2024-0012'"))) return false;
  if (await queryOne("SELECT id FROM bus_routes WHERE institution_id = $1 LIMIT 1", [NOOR])) {
    return false;
  }

  await transaction(async (tx) => {
    for (const [id, name, bus, plate, driver, supervisor, phone, [morning, afternoon], stops, riders] of BUS_LINES) {
      await tx.query(
        `INSERT INTO bus_routes (id, institution_id, name, bus_number, plate_number,
           driver_id, supervisor_name, supervisor_phone, capacity,
           school_morning_minute, school_afternoon_minute)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 26, $9, $10)`,
        [id, NOOR, name, bus, plate, driver, supervisor, phone, morning, afternoon],
      );
      for (const [position, [stopId, stopName, landmark, lat, lng, am, pm]] of stops.entries()) {
        await tx.query(
          `INSERT INTO bus_stops (id, route_id, position, name, landmark, latitude,
             longitude, morning_minute, afternoon_minute)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
          [stopId, id, position, stopName, landmark, lat, lng, am, pm],
        );
      }
      for (const [student, stopId] of riders) {
        await tx.query(
          "INSERT INTO route_students (student_id, route_id, stop_id) VALUES ($1, $2, $3)",
          [student, id, stopId],
        );
      }
    }
  });

  return true;
}

/** Fills an empty database. Returns true if it did. */
async function seedDemoData() {
  if (!wantDemo()) return false;
  if (await queryOne("SELECT id FROM institutions WHERE id = $1", [NOOR])) return false;

  // Online, nobody can sign in to the demo with a password: only through
  // "Try the demo". On this PC, the demo password works.
  const password = config.isProduction
    ? require("crypto").randomBytes(32).toString("hex")
    : config.demoPassword;
  const passwordHash = await bcrypt.hash(password, 10);

  await transaction(async (tx) => {
    await tx.query(
      `INSERT INTO institutions (id, name, type, city, address, latitude, longitude) VALUES
         ($1, 'Al-Noor Preparatory School', 'school', 'Baghdad', 'Al-Mansour, Baghdad', 33.315, 44.365),
         ($2, 'Al-Noor Intermediate School', 'school', 'Baghdad', 'Al-Mansour, Baghdad', 33.315, 44.365)`,
      [NOOR, NOOR_INTERMEDIATE],
    );

    for (const u of users) {
      await tx.query(
        `INSERT INTO users (id, institution_id, role, name, email, phone,
                            password_hash, class_name, subject_name, is_active)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
        [
          u.id,
          u.institution,
          u.role,
          u.name,
          u.email,
          u.phone,
          passwordHash,
          u.className ?? null,
          u.subjectName ?? null,
          u.isActive ?? true,
        ],
      );
    }

    await tx.query(
      `INSERT INTO parent_children (parent_id, child_id) VALUES
         ('PAR-2026-0142', 'STU-2026-0142'),
         ('PAR-2026-0142', 'STU-2026-0388'),
         ('PAR-2026-0150', 'STU-2026-0153'),
         ('PAR-2026-0151', 'STU-2026-0154'),
         ('PAR-2026-0152', 'STU-2026-0157')`,
    );

    for (const institution of [NOOR, NOOR_INTERMEDIATE]) {
      const yearId = institution === NOOR ? YEAR : `${YEAR}-${institution}`;
      await tx.query(
        `INSERT INTO academic_years
           (id, institution_id, name, start_date, end_date, is_current)
         VALUES ($1, $2, '2026–2027', '2026-09-20', '2027-06-10', true)`,
        [yearId, institution],
      );
      await tx.query(
        `INSERT INTO terms (academic_year_id, name, start_date, end_date) VALUES
           ($1, 'First semester', '2026-09-20', '2027-01-21'),
           ($1, 'Second semester', '2027-02-07', '2027-06-10')`,
        [yearId],
      );
      if (institution === NOOR) {
        for (const [title, type, audience, date, time, place, details] of events) {
          await tx.query(
            `INSERT INTO school_events (institution_id, title, type, audience,
                                        event_date, start_time, place, details)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
            [institution, title, type, audience, date, time, place, details],
          );
        }
      }
      for (const [name, type, start, end] of holidays) {
        await tx.query(
          `INSERT INTO holidays (academic_year_id, name, type, start_date, end_date)
           VALUES ($1, $2, $3, $4, $5)`,
          [yearId, name, type, start, end],
        );
      }
    }
  });

  return true;
}

/**
 * The whole demo school, step by step (each step only adds what is missing).
 * In Arabic when DEMO_LANGUAGE is ar: translated before the activity history,
 * so its lines are written with the Arabic names. Returns what was added.
 */
async function seedDemoSchool({ beforeHistory } = {}) {
  const added = [];
  const step = async (name, run) => {
    if (await run()) added.push(name);
  };
  await step("people and the study year", seedDemoData);
  await step("subjects and classes", seedAcademics);
  await step("announcements", seedAnnouncements);
  await step("timetable", seedTimetable);
  await step("bus lines", seedTransport);
  await step("fees", seedFinance);
  // Platform defaults the demo needs (official holidays, bell times).
  if (beforeHistory?.defaults) await beforeHistory.defaults();
  await step("attendance", seedAttendance);
  await step("exams", seedExams);
  await step("homework", seedAssignments);
  await step("chats", seedMessages);
  await step("study material and tasks", seedTasksAndResources);
  if (added.length > 0 && config.demoLanguage === "ar") {
    await require("./demo-arabic").arabize(DEMO_SCHOOLS);
  }
  await step("activity history", seedActivityLog);
  return added;
}

module.exports = {
  DEMO_SCHOOLS,
  DEMO_ACCOUNTS,
  seedDemoSchool,
  seedDemoData,
  seedAcademics,
  seedAnnouncements,
  seedTimetable,
  seedAttendance,
  seedExams,
  seedAssignments,
  seedMessages,
  seedFinance,
  seedTasksAndResources,
  seedActivityLog,
  seedTransport,
};
