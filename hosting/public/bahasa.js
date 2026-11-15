// Bahasa (Indonesia, Inggris, Arab) dan tema (terang/gelap) halaman unduh MyQuran.
// Teks Indonesia ada di HTML sebagai bahasa asal; kamus di bawah hanya memuat Inggris dan Arab.
// Terjemahan Inggris dan Arab ditulis untuk halaman pemasaran ini, bukan untuk ayat Al-Qur’an.
// Tanpa pelacak. Pilihan disimpan di localStorage bila tersedia.
(function () {
  'use strict';

  var root = document.documentElement;
  var LKEY = 'myquran.bahasa';
  var TKEY = 'myquran.tema';

  var D = {
    en: {
      'skip': 'Skip to content',
      'nav.fitur': 'Features', 'nav.pasang': 'Install', 'nav.faq': 'FAQ', 'nav.sumber': 'Sources',
      'top.unduh': 'Download',
      'lang.aria': 'Language',
      'th.dark': 'Dark mode', 'th.light': 'Light mode',
      'm.on': 'Motion effects: on', 'm.off': 'Motion effects: off',
      'title': 'MyQuran: read, learn, and memorise the Qur’an',
      'desc': 'MyQuran is a free Android app for reading the Qur’an, learning tajweed, and memorising. No ads, no purchases, and it works without internet.',
      'hero.eyebrow': 'Android app · Free',
      'hero.l1': 'Read, learn, and', 'hero.l2': 'memorise the Qur’an', 'hero.l3': 'in peace.',
      'hero.lead': 'MyQuran brings reading, recitation, tajweed lessons, memorisation, and prayer times together in one calm app.',
      'hero.cta': 'Download Android APK', 'hero.fitur': 'See the features',
      'hero.langnote': 'The app interface is in Indonesian. Qur’an translations are available in several languages.',
      'meta.default': 'Android 7.0 or newer · APK file',
      'alt.hero': 'MyQuran home: the next prayer and one step for today',
      'r.baca': 'Read', 'r.dengar': 'Listen', 'r.belajar': 'Learn', 'r.hafal': 'Memorise', 'r.salat': 'Pray',
      'promise.h': 'Calm. No ads. No cost.',
      'f1.t': 'Free', 'f1.d': 'No purchases and no subscriptions.',
      'f2.t': 'No ads', 'f2.d': 'No ads and no selling of data.',
      'f3.t': 'Offline', 'f3.d': 'Verse text and the Indonesian translation are stored on your phone.',
      'f4.t': 'Open', 'f4.d': 'MIT-licensed code that anyone can inspect.',
      'story.eyebrow': 'One app, five habits', 'story.h': 'From the first letter to memorisation.',
      'ch1.t': 'Read verse by verse',
      'ch1.p': 'Verse cards with the Uthmani text and the translation below. Tap a coloured letter to see the tajweed rule, an example word in that verse, and a listen button.',
      'ch1.c1': 'Colour-coded tajweed', 'ch1.c2': 'Translations in several languages', 'ch1.c3': 'Search and jump to a verse',
      'alt.baca': 'Verse card with colour-coded tajweed letters and the Indonesian translation',
      'ch2.t': 'One step for today',
      'ch2.p': 'Home shows the next prayer and one step worth taking now: a session of about 10 minutes, a review, or carrying on reading.',
      'ch2.c1': 'Next prayer', 'ch2.c2': '~10-minute session', 'ch2.c3': 'Reviews due',
      'alt.beranda': 'Home: prayer times and today’s session card',
      'ch3.t': 'Listen and follow along',
      'ch3.p': 'The verse being recited is highlighted and scrolls along. Recitation keeps playing in the background with lock-screen controls, even when the screen is off.',
      'ch3.c1': 'Repeat a verse or range', 'ch3.c2': 'Sleep timer and speed', 'ch3.c3': 'Download per surah',
      'alt.murottal': 'Verse-by-verse recitation with the playing verse highlighted',
      'ch4.t': 'Learn to read from zero',
      'ch4.p': 'A step-by-step path from the Arabic letters to tajweed, with a daily session of about 10 minutes. Listen to a reciter, then record yourself and compare. You judge your own reading; the app never grades it.',
      'ch4.c1': 'Pick your starting point', 'ch4.c2': 'Missed questions repeat', 'ch4.c3': 'Advanced lessons marked DRAFT',
      'alt.belajar': 'Learn tab: a path from the Arabic letters and today’s session card',
      'ch5.t': 'Scheduled memorisation',
      'ch5.p': 'Ziyadah, murajaah, and tasmi’ in one place, with a daily verse target. Review gaps grow 1, 3, 7, 14, then 30 days when you are fluent, stay put when unsure, and drop back to 1 day when you slip.',
      'ch5.c1': 'Record your own reading', 'ch5.c2': 'Stored on your phone',
      'alt.hafalan': 'Memorisation tab: today’s ziyadah and reviews that are due',
      'more.h': 'And much more.',
      'salat.h': 'Prayer',
      'salat.1': 'Prayer times using the Indonesian Ministry of Religious Affairs method (AlAdhan data), with automatic location or a city of your choice.',
      'salat.2': 'Reminders for each prayer, for recitation, and for today’s session.',
      'salat.3': 'Qibla direction with GPS and compass.',
      'progres.h': 'Progress',
      'progres.1': 'A daily reading goal of 5–30 minutes, streaks, a heatmap, and a khatam plan.',
      'progres.2': 'Verse bookmarks in General, Memorisation, and Favourites collections.',
      'progres.3': 'Resume from where you stopped, plus a distraction-free focus mode.',
      'tampil.h': 'Appearance',
      'tampil.1': 'Light, Dark, or Automatic theme; Green, Sepia, or High-contrast palette.',
      'tampil.2': 'Ivory, Sepia, or Night paper for reading.',
      'tampil.3': 'Adjustable size and line spacing for the Arabic text.',
      'values.h': 'How we look after the content.',
      'v1.t': 'Verses are never retyped',
      'v1.p': 'Verse text and translations are taken exactly from licensed datasets: never retyped, never AI-generated, never altered. The source and version are shown in the app (Me › Sources & licences).',
      'v2.t': 'Advanced lessons are marked DRAFT',
      'v2.p': 'Tajweed lessons for stages 6–16 were written with AI help and have not been checked by a tajweed teacher, so they carry a DRAFT label. Check them with your teacher. The explanation of how to read each rule is intentionally left blank until a teacher writes it.',
      'v3.t': 'Comfortable for every eye',
      'v3.p': 'Text contrast of at least 4.5 : 1 in light and dark themes, large-text support, a high-contrast palette, and your <em>reduce motion</em> setting is respected.',
      'get.eyebrow': 'Android · Free', 'get.h': 'Start with one step today.',
      'get.lead': 'Download, open, and carry on from wherever you left off. No account needed.',
      'pasang.h': 'How to install',
      'p.s1': '<strong>Download</strong> the <code>myquran.apk</code> file with the button above.',
      'p.s2': '<strong>Open</strong> the file. If Android asks, allow installs from the browser you are using.',
      'p.s3': '<strong>Done.</strong> Updates appear inside the app. Install the new version over the old one without uninstalling first, so your progress stays.',
      'p.small': 'Requires Android 7.0 or newer. Every version is signed with the same release key.',
      'aman.h': 'Make sure your download is genuine',
      'aman.label': 'SHA-256 of the file',
      'sha.loading': 'Loading from GitHub…',
      'copy': 'Copy', 'copied': 'Copied',
      'a.s1': 'On Windows, open Terminal in the download folder and run <code>certutil -hashfile myquran.apk SHA256</code>. On macOS or Linux: <code>sha256sum myquran.apk</code>.',
      'a.s2': 'Compare it with the string above. It must match <strong>exactly</strong>; if it differs, do not install.',
      'a.s3': 'Download only from this page.',
      'versi.h': 'Release notes',
      'versi.langnote': 'Release notes are written in Indonesian.',
      'versi.loading': 'Loading release notes…',
      'versi.prev': 'Previous versions',
      'versi.new': 'What’s new in version {v}',
      'versi.fail': 'Release notes cannot be loaded from GitHub right now.',
      'dl': 'Download',
      'meta.ver': 'Version {v}', 'meta.android': 'Android 7.0 or newer',
      'sha.fail': 'Could not load from GitHub right now. Open the releases page to see the SHA-256: ',
      'faq.h': 'Frequently asked questions.',
      'q1': 'Is MyQuran really free?',
      'a1': 'Yes. There are no ads, purchases, or subscriptions. MyQuran is a student, non-commercial project. The Ministry of Religious Affairs translation from Tanzil may only be used non-commercially, which is one reason the app stays free.',
      'q2': 'Do I need internet?',
      'a2': 'The verse text and the Indonesian translation are already on your phone, so you can read without internet. Other translations can be downloaded for offline reading. Recitation can be downloaded per surah, and there is a data-saver mode.',
      'q3': 'Which languages are supported?',
      'a3': 'The app interface is currently in Indonesian only. Qur’an translations are available in several languages (Indonesian, English, and others) and can be chosen in the reader.',
      'q4': 'Is there an iPhone or Google Play version?',
      'a4': 'Not yet. MyQuran is Android-only for now, and the Google Play version has not been released. The APK on this page is the official way to install it.',
      'q5': 'Why do I see an “unknown source” warning?',
      'a5': 'Android or Play Protect shows it for any app from outside the Play Store, so it is normal. The source code is open for anyone to inspect, and you can compare the file’s SHA-256 in the “Make sure your download is genuine” section.',
      'q6': 'How do I update the app?',
      'a6': 'The app checks for a new version at most once a day and shows a <strong>Download</strong> button when there is one. Install it over the old version without uninstalling, so your progress stays.',
      'q7': 'What data is stored, and how do I delete it?',
      'a7': 'All progress is stored on your phone. Signing in with Google is optional and only syncs reading sessions, bookmarks, and daily-session dates. Your voice recordings are never uploaded. You can delete your account and cloud data at any time from the app (Me › profile card › Delete account & cloud data) or on the <a href="hapus-akun">account deletion page</a>. Details are in the <a href="privacy">privacy policy</a> (in Indonesian).',
      'q8': 'Found a mistake in the text or translation, or a bug?',
      'a8': 'Please report it through <a href="https://github.com/ZainulArkaanAlinsi/Qur-an_App/issues">GitHub Issues</a>. Mistakes in verse text or translations are especially helpful to report.',
      'src.h': 'Data sources and licences.',
      'th.data': 'Data', 'th.src': 'Source', 'th.lic': 'Licence / terms',
      'r1.a': 'Qur’an text', 'r1.c': 'CC BY 3.0, exact copy',
      'r2.a': 'Indonesian translation', 'r2.b': 'Indonesian Ministry of Religious Affairs (via Tanzil)', 'r2.c': 'Non-commercial, with attribution',
      'r3.a': 'Other translations', 'r3.c': 'Unchanged; source and version credited',
      'r4.a': 'Tajweed colours',
      'r5.a': 'Recitation audio', 'r5.c': 'Recordings belong to the reciters and publishers',
      'r6.a': 'Prayer times', 'r6.c': 'Free API',
      'r7.a': 'Fonts',
      'src.note': 'The app code is licensed under <a href="https://github.com/ZainulArkaanAlinsi/Qur-an_App/blob/main/LICENSE">MIT</a>, which covers only code and documents made by the owner. The Qur’an text, translations, tajweed data, fonts, and the MyQuran logo and identity remain under their own owners’ licences (<a href="https://github.com/ZainulArkaanAlinsi/Qur-an_App/blob/main/NOTICE">NOTICE</a>).',
      'road.h': 'In progress.',
      'road1.t': 'One- and two-page mushaf view',
      'road1.d': 'The code is ready but not switched on yet. It is waiting for a supporting server, production data access, and a written copy of the permission.',
      'road2.t': 'Teacher review of advanced tajweed lessons',
      'road2.d': 'Madd, advanced tajweed, and gharib. The DRAFT label comes off after two teachers approve.',
      'foot.about': 'Made by Zainul Arkaan as a non-commercial student project. May it be of benefit.',
      'foot.privacy': 'Privacy policy', 'foot.hapus': 'Delete account', 'foot.kode': 'Source code', 'foot.lapor': 'Report a problem'
    },
    ar: {
      'skip': 'تخطَّ إلى المحتوى',
      'nav.fitur': 'المزايا', 'nav.pasang': 'التثبيت', 'nav.faq': 'الأسئلة الشائعة', 'nav.sumber': 'المصادر',
      'top.unduh': 'تنزيل',
      'lang.aria': 'اللغة',
      'th.dark': 'الوضع الداكن', 'th.light': 'الوضع الفاتح',
      'm.on': 'المؤثرات الحركية: مفعّلة', 'm.off': 'المؤثرات الحركية: متوقفة',
      'title': 'MyQuran: اقرأ القرآن وتعلّم التجويد واحفظ',
      'desc': 'MyQuran تطبيق أندرويد مجاني لقراءة القرآن وتعلّم التجويد والحفظ. بلا إعلانات ولا مشتريات، ويعمل دون إنترنت.',
      'hero.eyebrow': 'تطبيق أندرويد · مجاني',
      'hero.l1': 'اقرأ، وتعلّم، واحفظ', 'hero.l2': 'القرآن الكريم', 'hero.l3': 'بسكينة وطمأنينة.',
      'hero.lead': 'يجمع MyQuran القراءة والتلاوة وتعلّم التجويد والحفظ ومواقيت الصلاة في تطبيق واحد هادئ.',
      'hero.cta': 'تنزيل ملف APK لأندرويد', 'hero.fitur': 'استعرض المزايا',
      'hero.langnote': 'واجهة التطبيق باللغة الإندونيسية، وتتوفر ترجمات معاني القرآن بعدة لغات.',
      'meta.default': 'أندرويد 7.0 أو أحدث · ملف APK',
      'alt.hero': 'الشاشة الرئيسية في MyQuran: الصلاة القادمة وخطوة واحدة لهذا اليوم',
      'r.baca': 'اقرأ', 'r.dengar': 'استمع', 'r.belajar': 'تعلّم', 'r.hafal': 'احفظ', 'r.salat': 'صلِّ',
      'promise.h': 'هدوء. بلا إعلانات. بلا تكلفة.',
      'f1.t': 'مجاني', 'f1.d': 'بلا مشتريات ولا اشتراكات.',
      'f2.t': 'بلا إعلانات', 'f2.d': 'لا إعلانات ولا بيع للبيانات.',
      'f3.t': 'دون إنترنت', 'f3.d': 'نص الآيات والترجمة الإندونيسية محفوظان على هاتفك.',
      'f4.t': 'مفتوح المصدر', 'f4.d': 'الشيفرة برخصة MIT ويمكن لأي أحد فحصها.',
      'story.eyebrow': 'تطبيق واحد، خمس عادات', 'story.h': 'من الحرف الأول إلى الحفظ.',
      'ch1.t': 'اقرأ آية آية',
      'ch1.p': 'بطاقات لكل آية مع الرسم العثماني والترجمة أسفلها. المس حرفًا ملوّنًا لترى اسم حكم التجويد ومثالًا من الآية وزر الاستماع.',
      'ch1.c1': 'تجويد ملوّن', 'ch1.c2': 'ترجمات بعدة لغات', 'ch1.c3': 'بحث وانتقال إلى آية',
      'alt.baca': 'بطاقة آية بحروف تجويد ملوّنة وترجمة إندونيسية',
      'ch2.t': 'خطوة واحدة لهذا اليوم',
      'ch2.p': 'تعرض الشاشة الرئيسية الصلاة القادمة وخطوة واحدة تستحق أن تبدأها الآن: جلسة نحو ١٠ دقائق أو مراجعة أو متابعة القراءة.',
      'ch2.c1': 'الصلاة القادمة', 'ch2.c2': 'جلسة نحو ١٠ دقائق', 'ch2.c3': 'مراجعات مستحقة',
      'alt.beranda': 'الشاشة الرئيسية: مواقيت الصلاة وبطاقة جلسة اليوم',
      'ch3.t': 'استمع وتابع الآيات',
      'ch3.p': 'تُبرَز الآية التي تُتلى وتتحرك معها الشاشة. تستمر التلاوة في الخلفية مع أزرار التحكم في شاشة القفل حتى عند إطفاء الشاشة.',
      'ch3.c1': 'كرّر آية أو مقطعًا', 'ch3.c2': 'مؤقّت النوم والسرعة', 'ch3.c3': 'تنزيل لكل سورة',
      'alt.murottal': 'تلاوة آية آية مع إبراز الآية الجارية',
      'ch4.t': 'تعلّم القراءة من الصفر',
      'ch4.p': 'مسار متدرّج من الحروف الهجائية إلى التجويد مع جلسة يومية نحو ١٠ دقائق. استمع إلى القارئ ثم سجّل صوتك وقارن. أنت من يقيّم قراءتك؛ التطبيق لا يقيّمها.',
      'ch4.c1': 'اختر نقطة البداية', 'ch4.c2': 'تُعاد الأسئلة الخاطئة', 'ch4.c3': 'الدروس المتقدمة موسومة «مسودة»',
      'alt.belajar': 'تبويب التعلّم: مسار من الحروف الهجائية وبطاقة جلسة اليوم',
      'ch5.t': 'حفظ مجدول',
      'ch5.p': 'الزيادة والمراجعة والتسميع في مكان واحد مع هدف يومي للآيات. تتسع فترات المراجعة: ١ ثم ٣ ثم ٧ ثم ١٤ ثم ٣٠ يومًا عند الإتقان، وتبقى كما هي عند التردد، وتعود إلى يوم واحد عند الخطأ.',
      'ch5.c1': 'سجّل قراءتك بنفسك', 'ch5.c2': 'محفوظ على هاتفك',
      'alt.hafalan': 'تبويب الحفظ: زيادة اليوم والمراجعات المستحقة',
      'more.h': 'والمزيد أيضًا.',
      'salat.h': 'الصلاة',
      'salat.1': 'مواقيت الصلاة بطريقة وزارة الشؤون الدينية الإندونيسية (بيانات AlAdhan) مع تحديد الموقع تلقائيًا أو اختيار مدينة.',
      'salat.2': 'تذكيرات لكل صلاة وللتلاوة ولجلسة اليوم.',
      'salat.3': 'اتجاه القبلة بالـGPS والبوصلة.',
      'progres.h': 'التقدّم',
      'progres.1': 'هدف قراءة يومي من ٥ إلى ٣٠ دقيقة، وسلسلة الاستمرار، وخريطة حرارية، وخطة ختمة.',
      'progres.2': 'علامات للآيات في مجموعات: عامة وحفظ ومفضّلة.',
      'progres.3': 'تابع من آخر موضع قرأتَه، مع وضع تركيز بلا مشتّتات.',
      'tampil.h': 'المظهر',
      'tampil.1': 'سمة فاتحة أو داكنة أو تلقائية؛ وألوان خضراء أو بنية قديمة أو عالية التباين.',
      'tampil.2': 'ورق عاجي أو بني قديم أو ليلي للقراءة.',
      'tampil.3': 'حجم النص العربي وتباعد أسطره قابلان للضبط.',
      'values.h': 'كيف نحافظ على المحتوى.',
      'v1.t': 'لا تُعاد كتابة الآيات أبدًا',
      'v1.p': 'يُؤخذ نص الآيات والترجمات كما هو من مجموعات بيانات مرخّصة: بلا إعادة كتابة ولا توليد بالذكاء الاصطناعي ولا تعديل. المصدر والإصدار مذكوران في التطبيق (أنا › المصادر والتراخيص).',
      'v2.t': 'الدروس المتقدمة موسومة «مسودة»',
      'v2.p': 'كُتبت دروس التجويد للمراحل ٦–١٦ بمساعدة الذكاء الاصطناعي ولم يراجعها معلّم تجويد، لذا تحمل وسم «مسودة». طابقها مع معلّمك. شرح طريقة قراءة كل حكم متروك فارغًا عمدًا إلى أن يكتبه معلّم.',
      'v3.t': 'مريح لكل العيون',
      'v3.p': 'تباين النص ٤٫٥ : ١ على الأقل في السمتين الفاتحة والداكنة، ودعم للنص الكبير، وألوان عالية التباين، ويُحترم إعداد <em>تقليل الحركة</em>.',
      'get.eyebrow': 'أندرويد · مجاني', 'get.h': 'ابدأ بخطوة واحدة اليوم.',
      'get.lead': 'نزّل التطبيق وافتحه وتابع من حيث توقفت. لا حاجة لحساب.',
      'pasang.h': 'طريقة التثبيت',
      'p.s1': '<strong>نزّل</strong> ملف <code>myquran.apk</code> بالزر أعلاه.',
      'p.s2': '<strong>افتح</strong> الملف. وإذا طلب أندرويد ذلك فاسمح بالتثبيت من المتصفح الذي تستخدمه.',
      'p.s3': '<strong>انتهينا.</strong> تظهر التحديثات داخل التطبيق. ثبّت الإصدار الجديد فوق القديم دون حذفه أولًا كي يبقى تقدّمك.',
      'p.small': 'يتطلب أندرويد 7.0 أو أحدث. كل إصدار موقَّع بمفتاح الإصدار نفسه.',
      'aman.h': 'تأكد من أصالة ملفك',
      'aman.label': 'بصمة SHA-256 للملف',
      'sha.loading': 'جارٍ التحميل من GitHub…',
      'copy': 'نسخ', 'copied': 'تم النسخ',
      'a.s1': 'في ويندوز افتح Terminal في مجلد التنزيل ونفّذ <code>certutil -hashfile myquran.apk SHA256</code>. وفي macOS أو لينكس: <code>sha256sum myquran.apk</code>.',
      'a.s2': 'قارنها بالسلسلة أعلاه. يجب أن تتطابق <strong>تمامًا</strong>؛ وإن اختلفت فلا تثبّت الملف.',
      'a.s3': 'نزّل من هذه الصفحة فقط.',
      'versi.h': 'ملاحظات الإصدارات',
      'versi.langnote': 'ملاحظات الإصدارات مكتوبة بالإندونيسية.',
      'versi.loading': 'جارٍ تحميل ملاحظات الإصدارات…',
      'versi.prev': 'الإصدارات السابقة',
      'versi.new': 'الجديد في الإصدار {v}',
      'versi.fail': 'تعذّر تحميل ملاحظات الإصدارات من GitHub حاليًا.',
      'dl': 'تنزيل',
      'meta.ver': 'الإصدار {v}', 'meta.android': 'أندرويد 7.0 أو أحدث',
      'sha.fail': 'تعذّر التحميل من GitHub حاليًا. افتح صفحة الإصدارات لرؤية SHA-256: ',
      'faq.h': 'الأسئلة الشائعة.',
      'q1': 'هل MyQuran مجاني فعلًا؟',
      'a1': 'نعم. لا إعلانات ولا مشتريات ولا اشتراكات. MyQuran مشروع طلابي غير تجاري. ترجمة وزارة الشؤون الدينية من Tanzil لا يجوز استخدامها إلا لأغراض غير تجارية، وهذا أحد أسباب بقاء التطبيق مجانيًا.',
      'q2': 'هل أحتاج إلى الإنترنت؟',
      'a2': 'نص الآيات والترجمة الإندونيسية موجودان على هاتفك، فيمكنك القراءة دون إنترنت. ويمكن تنزيل الترجمات الأخرى للقراءة دون اتصال، وكذلك تنزيل التلاوة لكل سورة، وهناك وضع لتوفير البيانات.',
      'q3': 'ما اللغات المدعومة؟',
      'a3': 'واجهة التطبيق حاليًا بالإندونيسية فقط. وتتوفر ترجمات معاني القرآن بعدة لغات (الإندونيسية والإنجليزية وغيرها) ويمكن اختيارها في شاشة القراءة.',
      'q4': 'هل توجد نسخة لآيفون أو Google Play؟',
      'a4': 'ليس بعد. MyQuran حاليًا لأندرويد فقط، ولم تصدر نسخة Google Play. ملف APK في هذه الصفحة هو الطريقة الرسمية للتثبيت.',
      'q5': 'لماذا تظهر رسالة «مصدر غير معروف»؟',
      'a5': 'يعرضها أندرويد أو Play Protect لأي تطبيق من خارج متجر Play، وهذا أمر طبيعي. الشيفرة المصدرية مفتوحة لفحص أي أحد، ويمكنك مطابقة بصمة SHA-256 للملف في قسم «تأكد من أصالة ملفك».',
      'q6': 'كيف أحدّث التطبيق؟',
      'a6': 'يتحقق التطبيق من وجود إصدار جديد مرة واحدة يوميًا على الأكثر ويعرض زر <strong>تنزيل</strong> عند توفره. ثبّته فوق الإصدار القديم دون حذفه كي يبقى تقدّمك.',
      'q7': 'ما البيانات المحفوظة وكيف أحذفها؟',
      'a7': 'كل التقدّم محفوظ على هاتفك. تسجيل الدخول بحساب Google اختياري ويزامن فقط جلسات القراءة والعلامات وتواريخ الجلسات اليومية. تسجيلاتك الصوتية لا تُرفع أبدًا. يمكنك حذف حسابك وبياناتك السحابية في أي وقت من التطبيق (أنا › بطاقة الملف الشخصي › حذف الحساب والبيانات السحابية) أو عبر <a href="hapus-akun">صفحة حذف الحساب</a>. التفاصيل في <a href="privacy">سياسة الخصوصية</a> (بالإندونيسية).',
      'q8': 'وجدت خطأً في النص أو الترجمة أو عطلًا؟',
      'a8': 'يُرجى الإبلاغ عنه عبر <a href="https://github.com/ZainulArkaanAlinsi/Qur-an_App/issues">GitHub Issues</a>. والإبلاغ عن أخطاء نص الآيات أو الترجمات مفيد جدًا.',
      'src.h': 'مصادر البيانات والتراخيص.',
      'th.data': 'البيانات', 'th.src': 'المصدر', 'th.lic': 'الترخيص / الشروط',
      'r1.a': 'نص القرآن', 'r1.c': 'CC BY 3.0، نسخة مطابقة',
      'r2.a': 'الترجمة الإندونيسية', 'r2.b': 'وزارة الشؤون الدينية الإندونيسية (عبر Tanzil)', 'r2.c': 'غير تجاري مع نسبة المصدر',
      'r3.a': 'ترجمات بلغات أخرى', 'r3.c': 'دون تعديل مع ذكر المصدر والإصدار',
      'r4.a': 'ألوان التجويد',
      'r5.a': 'تسجيلات التلاوة', 'r5.c': 'التسجيلات ملك للقرّاء وناشريها',
      'r6.a': 'مواقيت الصلاة', 'r6.c': 'واجهة برمجية مجانية',
      'r7.a': 'الخطوط',
      'src.note': 'رخصة شيفرة التطبيق <a href="https://github.com/ZainulArkaanAlinsi/Qur-an_App/blob/main/LICENSE">MIT</a> وتشمل الشيفرة والوثائق التي أعدّها المالك فقط. أما نص القرآن والترجمات وبيانات التجويد والخطوط وشعار MyQuran وهويته فتخضع لتراخيص أصحابها (<a href="https://github.com/ZainulArkaanAlinsi/Qur-an_App/blob/main/NOTICE">NOTICE</a>).',
      'road.h': 'قيد العمل.',
      'road1.t': 'عرض المصحف بصفحة وصفحتين',
      'road1.d': 'الشيفرة جاهزة لكنها غير مفعّلة بعد. بانتظار الخادم المساند وإتاحة البيانات الإنتاجية ونسخة مكتوبة من الإذن.',
      'road2.t': 'مراجعة المعلّمين لدروس التجويد المتقدمة',
      'road2.d': 'المدود والتجويد المتقدم والغريب. يُزال وسم «مسودة» بعد موافقة معلّمَين.',
      'foot.about': 'من إعداد Zainul Arkaan كمشروع طلابي غير تجاري. نسأل الله أن ينفع به.',
      'foot.privacy': 'سياسة الخصوصية', 'foot.hapus': 'حذف الحساب', 'foot.kode': 'الشيفرة المصدرية', 'foot.lapor': 'الإبلاغ عن مشكلة'
    }
  };

  function read(k) { try { return window.localStorage.getItem(k); } catch (e) { return null; } }
  function write(k, v) { try { window.localStorage.setItem(k, v); } catch (e) { /* abaikan */ } }

  var lang = 'id';
  var origTitle = document.title;
  var descEl = document.querySelector('meta[name="description"]');
  var origDesc = descEl ? descEl.getAttribute('content') : '';

  // Simpan teks asal (Indonesia) sekali, supaya bisa kembali.
  var items = [];
  Array.prototype.forEach.call(document.querySelectorAll('[data-i18n],[data-i18n-html],[data-i18n-alt],[data-i18n-aria]'), function (el) {
    var rec = { el: el };
    if (el.hasAttribute('data-i18n')) { rec.text = el.textContent; }
    if (el.hasAttribute('data-i18n-html')) { rec.html = el.innerHTML; }
    if (el.hasAttribute('data-i18n-alt')) { rec.alt = el.getAttribute('alt'); }
    if (el.hasAttribute('data-i18n-aria')) { rec.aria = el.getAttribute('aria-label'); }
    items.push(rec);
  });

  function dict() { return D[lang] || null; }

  // Terjemahan untuk teks yang dibuat skrip lain. Bahasa Indonesia memakai teks cadangan dari pemanggil.
  function t(key, fallback, vars) {
    var d = dict();
    var s = (d && d[key]) || fallback || '';
    if (vars) Object.keys(vars).forEach(function (k) { s = s.split('{' + k + '}').join(vars[k]); });
    return s;
  }

  function applyLang(next, persist) {
    lang = (next === 'en' || next === 'ar') ? next : 'id';
    var d = dict();
    items.forEach(function (rec) {
      var el = rec.el;
      if (rec.text !== undefined && el.hasAttribute('data-i18n')) {
        var key = el.getAttribute('data-i18n');
        el.textContent = (d && d[key] !== undefined) ? d[key] : rec.text;
      }
      if (rec.html !== undefined) {
        var hk = el.getAttribute('data-i18n-html');
        el.innerHTML = (d && d[hk] !== undefined) ? d[hk] : rec.html;
      }
      if (rec.alt !== undefined) {
        var ak = el.getAttribute('data-i18n-alt');
        el.setAttribute('alt', (d && d[ak] !== undefined) ? d[ak] : rec.alt);
      }
      if (rec.aria !== undefined) {
        var rk = el.getAttribute('data-i18n-aria');
        el.setAttribute('aria-label', (d && d[rk] !== undefined) ? d[rk] : rec.aria);
      }
    });

    root.setAttribute('lang', lang);
    root.setAttribute('dir', lang === 'ar' ? 'rtl' : 'ltr');
    document.title = (d && d.title) || origTitle;
    if (descEl) descEl.setAttribute('content', (d && d.desc) || origDesc);

    Array.prototype.forEach.call(document.querySelectorAll('.lang button'), function (b) {
      b.setAttribute('aria-pressed', b.getAttribute('data-lang') === lang ? 'true' : 'false');
    });
    paintTheme();
    if (persist) write(LKEY, lang);
    window.dispatchEvent(new CustomEvent('mq:lang', { detail: { lang: lang } }));
  }

  // Tema
  var themeBtn = document.getElementById('tema');
  var metaTheme = document.querySelector('meta[name="theme-color"]');

  function theme() { return root.getAttribute('data-theme') === 'dark' ? 'dark' : 'light'; }

  function paintTheme() {
    if (!themeBtn) return;
    // Tombol menawarkan mode kebalikan dari yang sedang aktif.
    var label = theme() === 'dark' ? t('th.light', 'Mode terang') : t('th.dark', 'Mode gelap');
    themeBtn.setAttribute('aria-label', label);
    themeBtn.setAttribute('title', label);
  }

  function setTheme(next, persist) {
    root.setAttribute('data-theme', next);
    if (persist) write(TKEY, next);
    if (metaTheme) metaTheme.setAttribute('content', next === 'dark' ? '#04231a' : '#003527');
    paintTheme();
  }

  if (themeBtn) {
    themeBtn.addEventListener('click', function () {
      setTheme(theme() === 'dark' ? 'light' : 'dark', true);
    });
  }
  if (window.matchMedia) {
    var mq = window.matchMedia('(prefers-color-scheme: dark)');
    var follow = function (e) { if (!read(TKEY)) setTheme(e.matches ? 'dark' : 'light', false); };
    if (mq.addEventListener) mq.addEventListener('change', follow);
  }

  Array.prototype.forEach.call(document.querySelectorAll('.lang button'), function (b) {
    b.addEventListener('click', function () { applyLang(b.getAttribute('data-lang'), true); });
  });

  window.MQ = {
    t: t,
    lang: function () { return lang; },
    locale: function () { return lang === 'ar' ? 'ar' : (lang === 'en' ? 'en-GB' : 'id-ID'); }
  };

  var stored = read(LKEY);
  var initial = stored;
  if (!initial) {
    // Pertama kali: ikuti bahasa peramban bila Arab atau Inggris, selain itu Indonesia.
    var nav = (navigator.languages && navigator.languages[0]) || navigator.language || 'id';
    initial = /^ar/i.test(nav) ? 'ar' : (/^en/i.test(nav) ? 'en' : 'id');
  }
  setTheme(theme(), false);
  applyLang(initial, false);
})();
