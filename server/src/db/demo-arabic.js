// The demo school in Arabic, like a real Iraqi school would type it: names,
// classes, subjects, rooms, announcements, homework, chats, the bus.
// arabize() runs after the demo data is made in English (the tests keep the
// English one) and before the activity history, which is then written from
// these Arabic names.
const { query } = require("./database");

const WORDS = {
  // ── The schools ──
  "Al-Noor Preparatory School": "إعدادية النور",
  "Al-Noor Intermediate School": "متوسطة النور",
  Baghdad: "بغداد",
  "Al-Mansour, Baghdad": "المنصور، بغداد",
  "First semester": "الفصل الأول",
  "Second semester": "الفصل الثاني",

  // ── People ──
  "Zainab Haider": "زينب حيدر",
  "Ali Haider": "علي حيدر",
  "Ahmed Kareem": "أحمد كريم",
  "Haider Jasim": "حيدر جاسم",
  "Salma Hashim": "سلمى هاشم",
  "Kadhim Jawad": "كاظم جواد",
  "Fatima Ali": "فاطمة علي",
  "Maryam Hussein": "مريم حسين",
  "Noor Abbas": "نور عباس",
  "Ali Hassan": "علي حسن",
  "Mustafa Kareem": "مصطفى كريم",
  "Hussein Adel": "حسين عادل",
  "Yousif Raad": "يوسف رعد",
  "Sara Mahdi": "سارة مهدي",
  "Hawraa Kadhim": "حوراء كاظم",
  "Duaa Saad": "دعاء سعد",
  "Ruqaya Salman": "رقية سلمان",
  "Zahraa Jaafar": "زهراء جعفر",
  "Aya Ahmed": "آية أحمد",
  "Abbas Naji": "عباس ناجي",
  "Rusul Hadi": "رسل هادي",
  "Tabarak Qasim": "تبارك قاسم",
  "Sara Hadi": "سارة هادي",
  "Omar Saleh": "عمر صالح",
  "Huda Jaber": "هدى جابر",
  "Rana Sami": "رنا سامي",
  "Yusuf Ali": "يوسف علي",
  "Bilal Nasser": "بلال ناصر",
  "Ali Hassan Sr.": "حسن علي",
  "Kareem Mahmoud": "كريم محمود",
  "Mahdi Saleh": "مهدي صالح",
  "Salam Hameed": "سلام حميد",
  "Abbas Fadhil": "عباس فاضل",
  "Ms. Iman Fadhil": "ست إيمان فاضل",
  "Ms. Rasha Kamil": "ست رشا كامل",
  "Mr. Omar Saleh": "أ. عمر صالح",
  "Ms. Huda Jaber": "ست هدى جابر",
  "Exams Office": "لجنة الامتحانات",
  "School Administration": "إدارة المدرسة",
  Library: "المكتبة",

  // ── Subjects ──
  Mathematics: "الرياضيات",
  Physics: "الفيزياء",
  Chemistry: "الكيمياء",
  Biology: "الأحياء",
  "Arabic Language": "اللغة العربية",
  English: "اللغة الإنكليزية",
  "Islamic Education": "التربية الإسلامية",
  "Computer Science": "الحاسوب",

  // ── Calendar ──
  "Mid-year break": "عطلة نصف السنة",
  "Sports day": "اليوم الرياضي",
  "School playground": "ساحة المدرسة",
  "Class photo day": "يوم صور الصف",
  "Wear the full uniform": "ارتدِ الزي المدرسي كاملاً",
  "Mathematics department meeting": "اجتماع قسم الرياضيات",
  "Staff room": "غرفة المدرّسين",
  "Parent–teacher meeting": "اجتماع أولياء الأمور",
  "Main hall": "القاعة الرئيسية",
  "2:00 – 5:00 pm, by class": "2:00 – 5:00 مساءً، حسب الصف",
  "Science fair": "معرض العلوم",
  "School courtyard": "ساحة المدرسة",
  "Trip to the Iraq Natural History Museum": "سفرة إلى متحف التاريخ الطبيعي العراقي",
  "Bring the signed permission slip": "أحضر ورقة الموافقة موقّعة",

  // ── Announcements ──
  "Mid-term exams timetable published": "صدر جدول امتحانات نصف السنة",
  "The mid-term exam timetable is now available in the Exams section. Exams start on the 16th and run for two weeks. Please arrive 15 minutes early and bring your student card.\n\nIf you have two exams on the same day, contact the exams office.":
    "جدول امتحانات نصف السنة متاح الآن في قسم الامتحانات. تبدأ الامتحانات يوم 16 وتستمر أسبوعين. يرجى الحضور قبل 15 دقيقة وإحضار هوية الطالب.\n\nإذا كان لديك امتحانان في اليوم نفسه، راجع لجنة الامتحانات.",
  "Chemistry lab moved to Thursday": "نُقل مختبر الكيمياء إلى الخميس",
  "This week's chemistry lab session is moved from Wednesday to Thursday, same time. Lab coats are required.":
    "نُقلت حصة مختبر الكيمياء هذا الأسبوع من الأربعاء إلى الخميس، في الوقت نفسه. صدرية المختبر مطلوبة.",
  "Parents are invited to meet teachers next Monday from 2:00 pm to 5:00 pm in the main hall. Booking a time slot is not required.":
    "ندعو أولياء الأمور للقاء المدرّسين يوم الاثنين القادم من 2:00 إلى 5:00 مساءً في القاعة الرئيسية. لا حاجة لحجز موعد.",
  "Library opening hours extended": "تمديد ساعات دوام المكتبة",
  "During the exam period the library will stay open until 6:00 pm from Sunday to Thursday.":
    "خلال فترة الامتحانات تبقى المكتبة مفتوحة حتى 6:00 مساءً من الأحد إلى الخميس.",
  "Class photos will be taken on Tuesday morning. Please wear the full school uniform.":
    "ستُلتقط صور الصفوف صباح الثلاثاء. يرجى ارتداء الزي المدرسي كاملاً.",

  // ── The bus ──
  "Al-Mansour line": "خط المنصور",
  "Al-Karrada line": "خط الكرادة",
  "Baghdad 41582": "بغداد 41582",
  "Baghdad 30917": "بغداد 30917",
  "Al-Ghazaliya": "الغزالية",
  "Al-Ghazaliya square": "ساحة الغزالية",
  "Al-Adel": "العدل",
  "Al-Adel mosque": "جامع العدل",
  "Hay Al-Jamia": "حي الجامعة",
  "Al-Jamia street": "شارع الجامعة",
  "Al-Yarmouk": "اليرموك",
  "Al-Yarmouk hospital": "مستشفى اليرموك",
  "Al-Mansour": "المنصور",
  "14th of Ramadan street": "شارع 14 رمضان",
  "Al-Karrada": "الكرادة",
  "Kahramana square": "ساحة كهرمانة",
  "Al-Jadriya": "الجادرية",
  "Al-Jadriya bridge": "جسر الجادرية",

  // ── Attendance and fees ──
  "Medical note received": "استُلم تقرير طبي",
  "Siblings at the school": "إخوة في المدرسة",
  "Top of his class": "الأول على صفه",

  // ── Exams ──
  "Algebra quiz": "اختبار الجبر",
  "Functions test": "امتحان الدوال",
  "Worksheet 3": "ورقة العمل 3",
  "Motion quiz": "اختبار الحركة",
  "Forces lab": "مختبر القوى",
  "Periodic table quiz": "اختبار الجدول الدوري",
  "Bonding test": "امتحان الأواصر",
  "Grammar quiz": "اختبار القواعد",
  "Poetry analysis": "تحليل قصيدة",
  "Reading test": "امتحان القراءة",
  "Vocabulary quiz": "اختبار المفردات",
  "Surat Al-Hujurat summary": "ملخص سورة الحجرات",
  "Spreadsheet basics": "أساسيات الجداول الإلكترونية",
  "Unit 4 vocabulary": "مفردات الوحدة 4",
  "November monthly exam": "امتحان شهر تشرين الثاني",
  "Quadratic equations": "المعادلات التربيعية",
  Functions: "الدوال",
  Inequalities: "المتباينات",
  Motion: "الحركة",
  "Newton's laws": "قوانين نيوتن",
  Forces: "القوى",
  "Periodic table": "الجدول الدوري",
  "Chemical bonding": "الأواصر الكيميائية",

  // ── Homework ──
  "Quadratic equations – worksheet 4": "المعادلات التربيعية – ورقة العمل 4",
  "Solve questions 1 to 12 on the worksheet. Show every step of your work; final answers alone will not get full marks.":
    "حلّ الأسئلة من 1 إلى 12 في ورقة العمل. اكتب كل خطوات الحل؛ الجواب النهائي وحده لا يأخذ الدرجة الكاملة.",
  "Lab report: rates of reaction": "تقرير المختبر: سرعة التفاعل",
  "Write up the experiment from Monday's lab. Include your hypothesis, method, results table, a graph and a short conclusion.":
    "اكتب تقرير تجربة مختبر يوم الاثنين: الفرضية، الطريقة، جدول النتائج، رسم بياني، واستنتاج قصير.",
  "Essay: a place I remember": "إنشاء: مكان لا أنساه",
  "Write 300–400 words about a place that matters to you. Use at least five of this unit's descriptive adjectives.":
    "اكتب 300–400 كلمة عن مكان يهمّك، واستعمل خمس صفات وصفية على الأقل من هذه الوحدة.",
  "Newton's laws quiz": "اختبار قوانين نيوتن",
  "Ten questions on the three laws. Answer on the sheet handed out in class.":
    "عشرة أسئلة عن القوانين الثلاثة. أجب على الورقة الموزّعة في الصف.",
  "Build a simple calculator": "برمجة آلة حاسبة بسيطة",
  "Make a calculator that adds, subtracts, multiplies and divides two numbers. Hand in your project file.":
    "اصنع آلة حاسبة تجمع وتطرح وتضرب وتقسم عددين، وسلّم ملف المشروع.",
  "Surat Al-Hujurat – lesson summary": "سورة الحجرات – ملخص الدرس",
  "Summarise the lessons of verses 10–13 in your own words.": "لخّص دروس الآيات 10–13 بأسلوبك.",
  "Clear and well organised. Add one more example next time.": "واضح ومنظّم. أضف مثالاً آخر في المرة القادمة.",
  "Analyse the imagery of the poem from lesson 7.": "حلّل الصور الفنية في قصيدة الدرس 7.",
  "Good understanding of the imagery. Watch your spelling.": "فهم جيد للصور الفنية. انتبه للإملاء.",

  // ── Chats ──
  "Sir, is question 7 on the worksheet about the discriminant?": "أستاذ، هل السؤال 7 في ورقة العمل عن المميّز؟",
  "Yes. Find b² − 4ac first, then decide how many roots there are.":
    "نعم. احسب b² − 4ac أولاً، ثم حدّد عدد الجذور.",
  "Thank you!": "شكراً أستاذ!",
  "Good evening, Ms. Huda. How is Zainab doing in Arabic this month?":
    "مساء الخير ست هدى. كيف مستوى زينب في العربي هذا الشهر؟",
  "Very well. Her poetry analysis was one of the best in the class.":
    "ممتاز. تحليلها للقصيدة كان من أفضل ما في الصف.",
  "Reminder: lab coats for Thursday's chemistry lab.": "تذكير: صدرية المختبر لمختبر الكيمياء يوم الخميس.",
  "Will the lab report be due next week?": "هل تسليم تقرير المختبر الأسبوع القادم؟",
  "Yes, three days after the lab.": "نعم، بعد المختبر بثلاثة أيام.",

  // ── Study material and tasks ──
  "Solving quadratic equations": "حل المعادلات التربيعية",
  "Forces simulation (PhET)": "محاكاة القوى (PhET)",
  "Chemical bonding explained": "شرح الأواصر الكيميائية",
  "Descriptive writing tips": "نصائح للكتابة الوصفية",
  "Review chapter 3 for the math mid-term": "مراجعة الفصل الثالث لامتحان الرياضيات",
  "Focus on functions and inequalities.": "ركّز على الدوال والمتباينات.",
  "Read 20 pages of the English novel": "قراءة 20 صفحة من الرواية الإنكليزية",
  "Bring lab coat": "إحضار صدرية المختبر",
  "Make flashcards for chemistry": "بطاقات مراجعة للكيمياء",
  "Return library book": "إرجاع كتاب المكتبة",
  "Print Islamic Education summary": "طباعة ملخص التربية الإسلامية",
};

const ORDINALS = { "1st": "الأول", "2nd": "الثاني", "3rd": "الثالث", "4th": "الرابع", "5th": "الخامس", "6th": "السادس" };
const STREAMS = { Scientific: "العلمي", Literary: "الأدبي", Intermediate: "المتوسط" };
const SECTIONS = { A: "أ", B: "ب", C: "ج", D: "د" };

/** One value in Arabic: patterns first (classes, rooms), then the words. */
function toArabic(text) {
  const cls = /^(\d(?:st|nd|rd|th)) (Scientific|Literary|Intermediate) – ([A-D])$/.exec(text);
  if (cls) return `${ORDINALS[cls[1]]} ${STREAMS[cls[2]]} – ${SECTIONS[cls[3]]}`;
  const room = /^(Room|Lab|Hall) (\w+)$/.exec(text);
  if (room) {
    const place = { Room: "القاعة", Lab: "المختبر", Hall: "القاعة" }[room[1]];
    return `${place} ${SECTIONS[room[2]] ?? room[2]}`;
  }
  if (text === "Computer Lab") return "مختبر الحاسوب";
  return WORDS[text] ?? text;
}

/**
 * Which rows are the demo school's, per table ($1 = the demo schools' IDs),
 * and the text columns to put in Arabic. Real schools' rows are never touched.
 */
const CLASSES = "SELECT id FROM classes WHERE institution_id = ANY($1)";
const PEOPLE = "SELECT id FROM users WHERE institution_id = ANY($1)";
const YEARS = "SELECT id FROM academic_years WHERE institution_id = ANY($1)";
const TABLES = {
  institutions: ["id = ANY($1)", ["name", "city", "address"]],
  users: ["institution_id = ANY($1)", ["name", "class_name", "subject_name"]],
  terms: [`academic_year_id IN (${YEARS})`, ["name"]],
  // Official holidays are translated for each reader already.
  holidays: [`academic_year_id IN (${YEARS}) AND official_key IS NULL`, ["name"]],
  school_events: ["institution_id = ANY($1)", ["title", "place", "details"]],
  subjects: ["institution_id = ANY($1)", ["name"]],
  classes: ["institution_id = ANY($1)", ["name"]],
  timetable_slots: [`class_id IN (${CLASSES})`, ["room"]],
  announcements: ["institution_id = ANY($1)", ["title", "body", "author_name"]],
  bus_routes: ["institution_id = ANY($1)", ["name", "plate_number", "supervisor_name"]],
  bus_stops: ["route_id IN (SELECT id FROM bus_routes WHERE institution_id = ANY($1))", ["name", "landmark"]],
  exams: [`class_id IN (${CLASSES})`, ["title", "room", "topics"]],
  assignments: [`class_id IN (${CLASSES})`, ["title", "description"]],
  submissions: [`assignment_id IN (SELECT id FROM assignments WHERE class_id IN (${CLASSES}))`, ["feedback"]],
  messages: ["conversation_id IN (SELECT id FROM conversations WHERE institution_id = ANY($1))", ["text"]],
  resources: [`class_id IN (${CLASSES})`, ["title"]],
  tasks: [`user_id IN (${PEOPLE})`, ["title", "note"]],
  student_discounts: [`student_id IN (${PEOPLE})`, ["reason"]],
  attendance_excuses: [`student_id IN (${PEOPLE})`, ["note"]],
};

/** The demo schools' text in Arabic (only values it knows change). */
async function arabize(institutionIds) {
  const existing = new Set(
    (await query(
      `SELECT table_name || '.' || column_name AS c FROM information_schema.columns
       WHERE table_schema = current_schema()`,
    )).map((r) => r.c),
  );
  for (const [table, [scope, columns]] of Object.entries(TABLES)) {
    for (const column of columns) {
      if (!existing.has(`${table}.${column}`)) continue;
      // Table and column names come from the list above, never from input.
      const values = await query(
        `SELECT DISTINCT ${column} AS v FROM ${table} WHERE ${scope} AND ${column} IS NOT NULL`,
        [institutionIds],
      );
      for (const { v } of values) {
        // A list column (exam topics): each item.
        const arabic = Array.isArray(v) ? v.map(toArabic) : toArabic(v);
        if (JSON.stringify(arabic) === JSON.stringify(v)) continue;
        await query(`UPDATE ${table} SET ${column} = $3 WHERE ${scope} AND ${column} = $2`, [
          institutionIds,
          v,
          arabic,
        ]);
      }
    }
  }
}

module.exports = { arabize, toArabic };
