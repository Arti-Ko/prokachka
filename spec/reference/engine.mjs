// Прокачка — эталон формулы опыта, версия 2.
// Источник правды для Swift (mac/Sources/ProkachkaCore) и Kotlin (android/app/src/main/java/.../core).
// После правки: node spec/reference/gen-vectors.mjs — и обе платформы снова должны пройти тесты.
//
// Опыт = База × Объём × Сам/с помощью × Рекорд/сложность × Интенсивность × Стрик × Разнообразие
//        × Повтор × Калибровка × Усталость + Бонусы

/* ---------- форматирование (ru-RU, как в интерфейсе) ---------- */
export const jsRound = Math.round;
export const fmt = n => Math.round(n).toLocaleString('ru-RU');
export const signed = n => (n > 0 ? '+' : n < 0 ? '−' : '') + fmt(Math.abs(n));
export const fmtK = k => (Math.round(k * 100) / 100).toLocaleString('ru-RU', { maximumFractionDigits: 2 });
export const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
export const plural = (n, a, b, c) => { const m10 = n % 10, m100 = n % 100; return m10 === 1 && m100 !== 11 ? a : m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14) ? b : c; };
export const days = n => `${n} ${plural(n, 'день', 'дня', 'дней')}`;
export const fmtDur = m => m >= 60 ? `${fmtK(Math.round(m / 6) / 10)} ч` : `${Math.round(m)} мин`;

/* ---------- навыки ---------- */
// norm — сколько минут дела дают объём ×1 (работа длиннее медитации).
export const CATS = {
  body:   { name: 'Тело', base: 40, norm: 30 },
  mind:   { name: 'Ум', base: 30, norm: 30 },
  work:   { name: 'Дело', base: 45, norm: 60 },
  home:   { name: 'Быт', base: 20, norm: 30 },
  people: { name: 'Связи', base: 25, norm: 30 },
  craft:  { name: 'Творчество', base: 35, norm: 45 },
  rest:   { name: 'Режим', base: 15, norm: 15 },
  misc:   { name: 'Прочее', base: 10, norm: 30 },
  quest:  { name: 'Квест', base: 0, norm: 30 },
};
export const SKILLS = ['body', 'mind', 'work', 'home', 'people', 'craft', 'rest'];

// \b в JS и ICU не видит кириллицу, поэтому границы слов — явные lookaround.
const R = s => new RegExp(s.replace(/<B>/g, '(?<![а-яa-z])').replace(/<E>/g, '(?![а-яa-z])'));

/* ---------- числа словами ---------- */
export const NUMBER_WORDS = {
  один: 1, одна: 1, одну: 1, одного: 1, два: 2, две: 2, двух: 2, три: 3, трех: 3, четыре: 4, четырех: 4,
  пять: 5, пяти: 5, шесть: 6, шести: 6, семь: 7, семи: 7, восемь: 8, восьми: 8, девять: 9, девяти: 9,
  десять: 10, десяти: 10, одиннадцать: 11, двенадцать: 12, тринадцать: 13, четырнадцать: 14, пятнадцать: 15,
  шестнадцать: 16, семнадцать: 17, восемнадцать: 18, девятнадцать: 19, двадцать: 20, двадцати: 20,
  тридцать: 30, тридцати: 30, сорок: 40, сорока: 40, пятьдесят: 50, пятидесяти: 50, шестьдесят: 60,
  семьдесят: 70, восемьдесят: 80, девяносто: 90, сто: 100, двести: 200, триста: 300, четыреста: 400,
  пятьсот: 500, тысяча: 1000, тысячу: 1000, тысячи: 1000, полтора: 1.5, полторы: 1.5,
};

/** Нижний регистр, ё → е, числа словами → цифры: «два с половиной» не поддерживаем, «двадцать пять» — да. */
export function prepare(raw) {
  let t = (raw || '').toLowerCase().replace(/ё/g, 'е');
  t = t.replace(/[а-я]+/g, w => (w in NUMBER_WORDS ? String(NUMBER_WORDS[w]) : w));
  t = t.replace(/(?<![\d.,])([2-9]0) ([1-9])(?![\d.,])/g, (_, a, b) => String(Number(a) + Number(b)));
  t = t.replace(/(?<![\d.,])([1-9]00) ([1-9]\d?)(?![\d.,])/g, (_, a, b) => String(Number(a) + Number(b)));
  t = t.replace(/(?<![а-я])пол (?=час|км|литр|стакан)/g, '0.5 ');
  return t;
}

const meaningful = t => t.replace(/[\s\d.,!?-]/g, '').length;

/* ---------- словарь навыков ---------- */
// Вес 3 — однозначное слово, 2 — сильное, 1 — слабое («сделал», «разобрал»).
export const CUES = [
  ['body', 2, R('трениров|тренил|спортзал|в зал|качал|качалк|кардио|бегал|побегал|пробеж|<B>бег<E>|отжим|отжал|подтяг|подтян|присед|планк|<B>пресс|плавал|проплыл|бассейн|<B>йог|растяжк|растянул|велосипед|велик|<B>вело|покатал|прогулк|гулял|пешком|ходьб|турник|подход|<B>жим|штанг|гантел|становую|становой|<B>тяг[аиу]<E>|футбол|баскетбол|волейбол|теннис|<B>бокс|единоборств|борьб|зарядк|разминк|фитнес|кроссфит|лыж|коньк|скакалк|танцевал|танц|<B>поход|\\d+\\s*шаг|workout|<B>gym<E>')],
  ['mind', 2, R('прочитал|прочел|дочитал|читал|книг|страниц|<B>глав[аыу]?<E>|<B>курс|урок|лекци|вебинар|выучил|изучил|<B>учил|английск|немецк|испанск|китайск|японск|<B>язык|конспект|экзамен|подкаст|<B>стат[ьи]|документальн|математ|алгебр|физик|литкод|leetcode|дуолинго|duolingo|шахмат|повторил|\\d+\\s*слов')],
  ['mind', 1, R('разобрал|решил|понял')],
  ['work', 2, R('отчет|<B>тз<E>|<B>фт<E>|задач|проект|<B>код|закодил|программ|алгоритм|функци|<B>фич|релиз|деплой|<B>баг|рефактор|коммит|ревью|встреч|созвон|митинг|презентаци|резюме|собеседован|клиент|заказ|договор|<B>письм|<B>почт|работал|<B>смен[ауы]?<E>|bpmn|диаграмм|таблиц|документаци|аналитик|<B>макет|верстк|бэклог|спринт|дедлайн|фриланс|подработк')],
  ['home', 2, R('убрал|уборк|пропылесос|помыл|вымыл|посуд|стирк|постирал|приготовил|готовил|сварил|испек|ремонт|починил|мусор|погладил|продукт|в магазин|закупил|полил|цвет[ыо]|огород|<B>дач[аеу]|собрал мебел|коммуналк|счета|<B>шкаф|гардероб|холодильник|разморозил')],
  ['people', 2, R('позвонил|встретился|встретилась|увиделся|увиделась|виделся|помог|подарок|подарил|поздравил|<B>мам|<B>пап|родител|<B>друг|подруг|<B>семь[яеию]|семьей|семейн|свидани|бабушк|дедушк|<B>брат|сестр|<B>сын|<B>доч|<B>дет[иья]|ребен|девушк|коллег|в гости|в гостях|пообщал|поговорил|волонтер|донор')],
  ['people', 2, R('созвонился с|созвонилась с')],
  ['craft', 2, R('нарисовал|рисовал|скетч|иллюстрац|сочинил|музык|трек|<B>бит<E>|видео|ролик|смонтировал|монтаж|<B>пост<E>|снял|фотограф|<B>фото|дизайн|стих|рассказ|гитар|пианино|синтез|рилс|вышивал|вязал|слепил|лепк|поделк|<B>блог|канал')],
  ['rest', 2, R('медитир|медитац|выспал|лег спать|рано лег|выпил воды|<B>л воды|литр|витамин|отдохнул|дыхательн|саун|<B>бан[яеию]|массаж|контрастн|<B>режим|детокс|<B>спал')],
  ['work', 1, R('сделал|написал|закрыл|сдал|доделал|закончил|запустил|занимал|поработал')],
];

/* ---------- минусы, отказы, планы ---------- */
export const MINUS = [
  { re: R('пропустил[а-я]* (тренир|зал|пробеж|йог|бег|заняти)'), xp: -30, cat: 'body', label: 'Пропуск тренировки' },
  { re: R('пропустил[а-я]* (пару|лекци|урок)|прогулял'), xp: -20, cat: 'mind', label: 'Прогул' },
  { re: R('проспал'), xp: -20, cat: 'rest', label: 'Проспал' },
  { re: R('залип|думскрол|листал[а-я]* (ленту|тикток|рилс|шортс)|в тикток|в соцсет|смотрел[а-я]* (тикток|рилс|шортс)'), xp: -10, perHour: true, cat: 'rest', label: 'Залип в ленте' },
  { re: R('курил|сигарет|вейп'), xp: -25, cat: 'rest', label: 'Курение' },
  { re: R('напил|бухал|алкогол|выпил[а-я]* (пив|вин|водк|коньяк|виски|шампанск)'), xp: -20, cat: 'rest', label: 'Алкоголь' },
  { re: R('фастфуд|бургер|чипс|газировк|объел|переел'), xp: -15, cat: 'rest', label: 'Вредная еда' },
  { re: R('прокрастин|ничего не сделал|ничего не делал|бездельнич|провалял|весь день лежал'), xp: -20, cat: 'work', label: 'Прокрастинация' },
  { re: R('сорвал[а-я]* на|наорал|накричал|нагрубил|поругал'), xp: -25, cat: 'people', label: 'Сорвался' },
  { re: R('опоздал'), xp: -10, cat: 'work', label: 'Опоздание' },
  { re: R('лег (спать )?в [2-5]<E>|(лег|лечь) поздно|поздно лег|не выспал'), xp: -15, cat: 'rest', label: 'Поздно лёг' },
  { re: R('импульсивн|лишн[а-я]* покупк|потратил[а-я]* (кучу|много)'), xp: -15, cat: 'home', label: 'Лишняя покупка' },
  { re: R('забыл|пропустил'), xp: -15, cat: 'work', label: 'Не сделал' },
];
export const ABSTAIN = R('<B>не (курил|пил|залипал|ел сладк|ел фастфуд|сидел в|пропустил|опоздал|проспал|сорвал|забыл|прокрастин)|без (сигарет|алкогол|сахара|сладкого|соцсет|телефона|фастфуда)|отказался от|удержался');
// «не пошел в зал», «не сделала зарядку»: отрицание глагола в прошедшем времени.
export const NEGATED = R('<B>не (?!только)[а-я]{2,}(ал|ял|ел|ил|ыл|ул|ла|ли|лся|лась|лись)<E>');
export const PLAN = R('<B>(завтра|потом|планирую|собираюсь|хочу|хотелось бы|надо|нужно|буду|пойду|поеду|сделаю|займусь|начну)<E>');
// Прошедшее время: «сделал», «пробежала». Слова короче 5 букв («зал», «стол») не считаются.
export const PAST = R('[а-я]{3,}(ал|ял|ел|ил|ыл|ул|ла|ли|лся|лась|лись)<E>');
export const isPlan = t => PLAN.test(t) && !PAST.test(t);

export const SELF = R('<B>(сам|сама|самостоятельно)<E>|с нуля|без помощи|без подсказ|своими руками');
export const HELPED = R('с помощью|по туториал|по видео|по гайду|с подсказк|chatgpt|<B>гпт|нейросет|claude|<B>с ии<E>');
export const RECORD = R('рекорд|<B>пб<E>|лучш[а-я]* результат');
export const HARD = R('сложн|трудн|тяжел|впервые|первый раз|наконец|непрост');
export const EASY = R('немного|чуть|быстро|слегка|легк');
export const INTENSE = R('интенсивн|до отказа|на максимум|выложил|выжал');

/* ---------- объём ---------- */
export function quantities(t) {
  const n = s => parseFloat(s.replace(',', '.'));
  const q = {};
  let m;
  if ((m = t.match(/(\d+(?:[.,]\d+)?)\s*(?:ч|час)[а-я]*\s*(\d+)\s*м/))) q.minutes = n(m[1]) * 60 + n(m[2]);
  else if ((m = t.match(/(\d+(?:[.,]\d+)?)\s*(?:ч(?![а-я])|час)/))) q.minutes = n(m[1]) * 60;
  else if ((m = t.match(/(\d+)\s*мин/))) q.minutes = n(m[1]);
  else if (/полчаса/.test(t)) q.minutes = 30;
  else if (/час с половиной/.test(t)) q.minutes = 90;
  else if (/весь день|целый день/.test(t)) q.minutes = 300;
  else if (/весь вечер|целый вечер/.test(t)) q.minutes = 180;
  else if (/(?<![а-я])час(?![а-я])/.test(t)) q.minutes = 60;
  if ((m = t.match(/(\d+(?:[.,]\d+)?)\s*(?:км|килом)/))) q.km = n(m[1]);
  else if ((m = t.match(/(?<![ч\d.,])(\d+)\s*(?:м(?![а-я])|метр)/))) q.km = n(m[1]) / 1000;
  if ((m = t.match(/(\d+)\s*шаг/))) q.steps = n(m[1]);
  if ((m = t.match(/(\d+)\s*стр/))) q.pages = n(m[1]);
  if ((m = t.match(/(\d+)\s*глав/))) q.chapters = n(m[1]);
  if ((m = t.match(/(\d+)\s*подход[а-я]*\s*по\s*(\d+)/))) q.reps = n(m[1]) * n(m[2]);
  else if ((m = t.match(/(\d+)\s*(?:раз(?:а|ов)?(?![а-я])|отжим|подтяг|присед|повтор)/))) q.reps = n(m[1]);
  if ((m = t.match(/(\d+)\s*(?:задач|тикет|баг)/))) q.tasks = n(m[1]);
  if ((m = t.match(/(\d+)\s*слов/))) q.words = n(m[1]);
  return q;
}

// Сон меряется своей нормой: 8 часов — это ×1, а не втрое больше медитации.
export const SLEEP = R('<B>спал|выспал|поспал|<B>сон<E>|<B>сна<E>');

/** Норма расстояния зависит от вида: 10 км на велосипеде — как 3 км бегом. */
export const DISTANCE = [
  [R('велосипед|велик|<B>вело|покатал'), 10],
  [R('плавал|проплыл|бассейн'), 1],
  [R('прогулк|гулял|пешком|прошел|прошла|ходьб'), 5],
];
export function distanceNorm(t) {
  for (const [re, km] of DISTANCE) if (re.test(t)) return km;
  return 3;
}

export function effortOf(q, cat, t) {
  const norms = [
    ['km', distanceNorm(t), v => `${fmtK(v)} км`],
    ['steps', 8000, v => `${v} шагов`],
    ['pages', 20, v => `${v} стр.`],
    ['chapters', 1, v => `${v} ${plural(v, 'глава', 'главы', 'глав')}`],
    ['reps', 30, v => `${v} повт.`],
    ['tasks', 2, v => `${v} ${plural(v, 'задача', 'задачи', 'задач')}`],
    ['words', 20, v => `${v} слов`],
    ['minutes', cat === 'rest' && SLEEP.test(t) ? 480 : CATS[cat].norm, v => fmtDur(v)],
  ];
  for (const [key, base, label] of norms) if (q[key] != null) return { k: clamp(Math.sqrt(q[key] / base), 0.5, 3), label: label(q[key]) };
  return null;
}

export function detectCat(t) {
  const score = {};
  for (const [cat, w, re] of CUES) if (re.test(t)) score[cat] = (score[cat] || 0) + w;
  let best = 'misc', top = 0;
  for (const c of SKILLS) if ((score[c] || 0) > top) { best = c; top = score[c]; }
  return best;
}

/** Множитель стрика: +3% за день до 10 дней, дальше +1% до +50% на 30-й день. */
export const streakK = s => 1 + Math.min(s, 10) * 0.03 + Math.max(0, Math.min(s, 30) - 10) * 0.01;

/** Почему текст не оценён: 'short' — мало слов, 'plan' — это намерение, а не дело. */
export function hint(raw) {
  const t = prepare(raw);
  if (!t.trim()) return null;
  if (meaningful(t) < 3) return 'short';
  if (isPlan(t)) return 'plan';
  return null;
}

/*
 * ctx: {
 *   dayActs: [{ cat, xp, text, label }]  — дела этого дня; text — prepare(текст), label — первая строка разбора
 *   streak: число дней подряд, считая сегодня, если сегодня уже был плюс
 *   cal: { навык: множитель } — калибровка из правок
 *   lastTrained: { навык: сколько дней назад был последний плюс } — только дни до сегодняшнего
 *   daysSinceAny: сколько дней назад был последний день с плюсом (null — истории нет)
 *   override: навык, выбранный вручную
 * }
 */
export function assess(raw, ctx) {
  const t = prepare(raw);
  if (meaningful(t) < 3 || isPlan(t)) return null;
  const steps = [];
  const q = quantities(t);
  const acts = ctx.dayActs;
  const positiveToday = acts.filter(a => a.xp > 0);

  const minusRule = !ABSTAIN.test(t) && (MINUS.find(m => m.re.test(t)) || (NEGATED.test(t) && { xp: -15, label: 'Не сделал', negated: true }));
  if (minusRule) {
    // «не пошел в зал» — минус тому навыку, о котором речь; не понятно о каком — Делу.
    const cat = minusRule.negated ? (detectCat(t) === 'misc' ? 'work' : detectCat(t)) : minusRule.cat;
    let xp = minusRule.xp;
    steps.push({ name: minusRule.label, val: signed(minusRule.xp) });
    if (minusRule.perHour) {
      const h = clamp((q.minutes ?? 60) / 60, 0.5, 6);
      xp *= h;
      steps.push({ name: `Время · ${fmtDur(h * 60)}`, val: `×${fmtK(h)}` });
    }
    const again = acts.filter(a => a.xp < 0 && a.label === minusRule.label).length;
    if (again > 0) {
      const k = Math.min(2, 1 + 0.5 * again);
      xp *= k;
      steps.push({ name: `Снова · ${again + 1}-й раз за день`, val: `×${fmtK(k)}` });
    }
    return { cat, xp: Math.round(xp), steps, sure: true };
  }

  const abstain = ABSTAIN.test(t);
  let cat, xp;
  if (abstain) {
    cat = 'rest'; xp = 20;
    steps.push({ name: 'Удержался', val: '20' });
  } else {
    cat = ctx.override || detectCat(t);
    xp = CATS[cat].base;
    steps.push({ name: `База · ${CATS[cat].name}`, val: String(xp) });
  }
  const mul = (name, k) => { xp *= k; steps.push({ name, val: `×${fmtK(k)}` }); };

  if (!abstain) {
    const eff = effortOf(q, cat, t);
    if (eff) mul(`Объём · ${eff.label}`, eff.k);
    if (SELF.test(t)) mul('Сам', 1.5); else if (HELPED.test(t)) mul('С помощью', 0.8);
    if (RECORD.test(t)) mul('Рекорд', 1.5); else if (HARD.test(t)) mul('Сложно', 1.3); else if (EASY.test(t)) mul('Легко', 0.7);
    if (INTENSE.test(t)) mul('Интенсивно', 1.2);
  }
  if (ctx.streak > 0) mul(`Стрик · ${days(ctx.streak)}`, streakK(ctx.streak));
  if (!abstain && SKILLS.includes(cat) && !positiveToday.some(a => a.cat === cat)) {
    const ago = ctx.lastTrained?.[cat];
    if (ago == null) mul('Новый навык', 1.2);
    else if (ago >= 3) mul(`Давно не качал · ${days(ago)}`, 1.2);
  }
  const same = positiveToday.filter(a => a.text === t).length;
  const reps = positiveToday.filter(a => a.cat === cat).length;
  if (same > 0) mul(`Повтор того же · ${same + 1}-й раз`, Math.pow(0.5, same));
  else if (reps > 0) mul(`Повтор · ${reps + 1}-й раз за день`, Math.pow(0.85, reps));
  const cal = ctx.cal[cat] ?? 1;
  if (Math.abs(cal - 1) > 0.001) mul('Твоя калибровка', cal);
  const dayXP = positiveToday.reduce((s, a) => s + a.xp, 0);
  if (dayXP >= 800) mul('Усталость дня · больше 800 XP', 0.5);
  else if (dayXP >= 500) mul('Усталость дня · больше 500 XP', 0.75);

  xp = Math.round(xp);
  if (positiveToday.length === 0) {
    xp += 10;
    steps.push({ name: 'Первое дело за день', val: '+10' });
    if (ctx.daysSinceAny != null && ctx.daysSinceAny >= 3) {
      xp += 20;
      steps.push({ name: 'С возвращением', val: '+20' });
    }
  }
  return { cat, xp, steps, sure: cat !== 'misc' };
}


/* ---------- уровни ---------- */
export const lvlReq = L => Math.round(100 * Math.pow(L, 1.4));
export const skillReq = L => Math.round(60 * Math.pow(L, 1.3));
export function levelInfo(total, req = lvlReq) {
  let level = 1, start = 0;
  while (total - start >= req(level)) { start += req(level); level++; }
  const need = req(level), into = total - start;
  return { level, start, into, need, p: into / need };
}
