// Эталон формулы опыта. Вырезан из design/prototype.html — по нему сверяются Swift и Kotlin.
// Не править руками: при изменении формулы правится прототип и пересобираются векторы.
const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = n => Math.round(n).toLocaleString('ru-RU');
const signed = n => (n > 0 ? '+' : n < 0 ? '−' : '') + fmt(Math.abs(n));
const fmtK = k => (Math.round(k * 100) / 100).toLocaleString('ru-RU', { maximumFractionDigits: 2 });
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
const plural = (n, a, b, c) => { const m10 = n % 10, m100 = n % 100; return m10 === 1 && m100 !== 11 ? a : m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14) ? b : c; };
const icon = name => `<svg class="i"><use href="#i-${name}"/></svg>`;
const days = n => `${n} ${plural(n, 'день', 'дня', 'дней')}`;

/* ---------- навыки и словарь ---------- */
const CATS = {
  body:   { name: 'Тело', base: 40, icon: 'heart', about: 'Тренировки, бег, прогулки, зарядка' },
  mind:   { name: 'Ум', base: 30, icon: 'book', about: 'Книги, курсы, языки, разбор новой темы' },
  work:   { name: 'Дело', base: 45, icon: 'briefcase', about: 'Работа, код, ТЗ, отчёты, свои проекты' },
  home:   { name: 'Быт', base: 20, icon: 'house', about: 'Уборка, готовка, ремонт, покупки' },
  people: { name: 'Связи', base: 25, icon: 'people', about: 'Семья, друзья, помощь, встречи' },
  craft:  { name: 'Творчество', base: 35, icon: 'pencil', about: 'Рисование, музыка, видео, посты' },
  rest:   { name: 'Режим', base: 15, icon: 'moon', about: 'Сон, вода, медитация, отказ от вредного' },
  misc:   { name: 'Прочее', base: 10, icon: 'sparkles', about: '' },
  quest:  { name: 'Квест', base: 0, icon: 'target', about: '' },
};
const SKILLS = ['body', 'mind', 'work', 'home', 'people', 'craft', 'rest'];
// \b в JS не видит кириллицу, поэтому границы слов через lookaround
const R = s => new RegExp(s.replace(/<B>/g, '(?<![а-яa-z])').replace(/<E>/g, '(?![а-яa-z])'));
const norm = s => s.toLowerCase().replace(/ё/g, 'е');

const CUES = [
  ['body', 2, R('трениров|спортзал|в зал|качал|кардио|бегал|побегал|пробеж|отжим|отжал|подтяг|подтян|присед|планк|плавал|бассейн|йог|растяжк|велосипед|прогулк|гулял|турник|футбол|бокс|зарядк|\\d+\\s*шаг')],
  ['mind', 2, R('прочитал|прочел|читал|книг|страниц|курс|урок|лекци|выучил|изучил|учил|разобрал|английск|конспект|экзамен|подкаст|\\d+\\s*слов')],
  ['work', 2, R('отчет|<B>тз<E>|<B>фт<E>|задач|проект|<B>код|программ|алгоритм|функци|фич|релиз|деплой|<B>баг|встреч|созвон|презентаци|резюме|собеседован|клиент|заказ|bpmn|диаграмм|таблиц|документаци|ревью')],
  ['home', 2, R('убрал|уборк|пропылесос|помыл|посуд|стирк|постирал|приготовил|готовил|ремонт|починил|мусор|погладил|продукт|в магазин')],
  ['people', 2, R('позвонил|встретился|помог|подарок|поздравил|<B>мам|<B>пап|<B>друг|подруг|семь|свидани|бабушк|<B>брат|сестр')],
  ['craft', 2, R('нарисовал|рисовал|сочинил|музык|трек|видео|смонтировал|монтаж|<B>пост<E>|снял|фотограф|дизайн|стих|рассказ|гитар|пианино|рилс')],
  ['rest', 2, R('медитир|медитац|выспал|лег спать|выпил воды|<B>л воды|литр|витамин|отдохнул|дыхательн')],
  ['work', 1, R('сделал|написал|закрыл|сдал|доделал|закончил|запустил')],
];
const MINUS = [
  { re: R('пропустил[а-я]* (тренир|зал|пробеж|йог|бег)'), xp: -30, cat: 'body', label: 'Пропуск тренировки' },
  { re: R('проспал'), xp: -20, cat: 'rest', label: 'Проспал' },
  { re: R('залип|думскрол|листал[а-я]* (ленту|тикток|рилс|шортс)|в тикток|в соцсет|смотрел[а-я]* (тикток|рилс|шортс)'), xp: -10, perHour: true, cat: 'rest', label: 'Залип в ленте' },
  { re: R('курил|сигарет|вейп'), xp: -25, cat: 'rest', label: 'Курение' },
  { re: R('напил|бухал|алкогол|выпил[а-я]* (пив|вин|водк|коньяк)'), xp: -20, cat: 'rest', label: 'Алкоголь' },
  { re: R('фастфуд|бургер|чипс|газировк|объел'), xp: -15, cat: 'rest', label: 'Вредная еда' },
  { re: R('прокрастин|ничего не сделал|бездельнич|провалял'), xp: -20, cat: 'work', label: 'Прокрастинация' },
  { re: R('сорвал[а-я]* на|наорал|нагрубил|поругал'), xp: -25, cat: 'people', label: 'Сорвался' },
  { re: R('опоздал'), xp: -10, cat: 'work', label: 'Опоздание' },
  { re: R('лег (спать )?в [2-5]<E>|(лег|лечь) поздно|поздно лег|не выспал'), xp: -15, cat: 'rest', label: 'Поздно лёг' },
  { re: R('<B>не (сделал|успел)|забыл|пропустил'), xp: -15, cat: 'work', label: 'Не сделал' },
];
const ABSTAIN = R('<B>не (курил|пил|залипал|ел сладк|ел фастфуд|сидел в)|без (сигарет|алкогол|сахара|сладкого|соцсет|телефона)');
const SELF = R('<B>(сам|сама|самостоятельно)<E>|с нуля|без помощи|без подсказ|своими руками');
const HELPED = R('с помощью|по туториал|по видео|по гайду|с подсказк|chatgpt|<B>гпт|нейросет|claude|<B>с ии<E>');
const HARD = R('сложн|трудн|тяжел|впервые|первый раз|наконец|непрост|рекорд');
const EASY = R('немного|чуть|быстро|слегка|легк');

const fmtDur = m => m >= 60 ? `${fmtK(Math.round(m / 6) / 10)} ч` : `${Math.round(m)} мин`;
function quantities(t) {
  const n = s => parseFloat(s.replace(',', '.'));
  const q = {};
  let m;
  if ((m = t.match(/(\d+(?:[.,]\d+)?)\s*(?:ч|час)[а-я]*\s*(\d+)\s*мин/))) q.minutes = n(m[1]) * 60 + n(m[2]);
  else if ((m = t.match(/(\d+(?:[.,]\d+)?)\s*(?:ч(?![а-я])|час)/))) q.minutes = n(m[1]) * 60;
  else if ((m = t.match(/(\d+)\s*мин/))) q.minutes = n(m[1]);
  else if (/полтора час/.test(t)) q.minutes = 90;
  else if (/полчаса/.test(t)) q.minutes = 30;
  else if (/весь день|целый день/.test(t)) q.minutes = 300;
  else if (/(?<![а-я])час(?![а-я])/.test(t)) q.minutes = 60;
  if ((m = t.match(/(\d+(?:[.,]\d+)?)\s*(?:км|килом)/))) q.km = n(m[1]);
  if ((m = t.match(/(\d+)\s*стр/))) q.pages = n(m[1]);
  if ((m = t.match(/(\d+)\s*(?:раз(?![а-я])|отжим|подтяг|присед)/))) q.reps = n(m[1]);
  if ((m = t.match(/(\d+)\s*задач/))) q.tasks = n(m[1]);
  if ((m = t.match(/(\d+)\s*слов/))) q.words = n(m[1]);
  return q;
}
const NORMS = [
  ['km', 3, v => `${fmtK(v)} км`],
  ['pages', 20, v => `${v} стр.`],
  ['reps', 30, v => `${v} повт.`],
  ['tasks', 2, v => `${v} ${plural(v, 'задача', 'задачи', 'задач')}`],
  ['words', 20, v => `${v} слов`],
  ['minutes', 30, v => fmtDur(v)],
];
function effortOf(q) {
  for (const [key, base, label] of NORMS) if (q[key] != null) return { k: clamp(Math.sqrt(q[key] / base), 0.5, 3), label: label(q[key]) };
  return null;
}
function detectCat(t) {
  const score = {};
  for (const [cat, w, re] of CUES) if (re.test(t)) score[cat] = (score[cat] || 0) + w;
  let best = 'misc', top = 0;
  for (const c of SKILLS) if ((score[c] || 0) > top) { best = c; top = score[c]; }
  return best;
}

/* ctx: { dayActs, streak, cal, override } */
function assess(raw, ctx) {
  const t = norm(raw || '');
  if (t.replace(/[\s\d.,!?-]/g, '').length < 3) return null;
  const steps = [];
  const q = quantities(t);
  const abstain = ABSTAIN.test(t);
  const minus = !abstain && MINUS.find(m => m.re.test(t));
  if (minus) {
    let xp = minus.xp;
    steps.push({ name: minus.label, val: signed(minus.xp) });
    if (minus.perHour) {
      const h = clamp((q.minutes ?? 60) / 60, 0.5, 6);
      xp = Math.round(xp * h);
      steps.push({ name: `Время · ${fmtDur(h * 60)}`, val: `×${fmtK(h)}` });
    }
    return { cat: minus.cat, xp, steps, sure: true };
  }
  let cat, xp;
  if (abstain) { cat = 'rest'; xp = 20; steps.push({ name: 'Удержался', val: '20' }); }
  else {
    cat = ctx.override || detectCat(t);
    xp = CATS[cat].base;
    steps.push({ name: `База · ${CATS[cat].name}`, val: String(xp) });
  }
  const mul = (name, k) => { xp *= k; steps.push({ name, val: `×${fmtK(k)}` }); };
  if (!abstain) {
    const eff = effortOf(q);
    if (eff) mul(`Объём · ${eff.label}`, eff.k);
    if (SELF.test(t)) mul('Сам', 1.5); else if (HELPED.test(t)) mul('С помощью', 0.8);
    if (HARD.test(t)) mul('Сложно', 1.3); else if (EASY.test(t)) mul('Легко', 0.7);
  }
  if (ctx.streak > 0) mul(`Стрик · ${days(ctx.streak)}`, 1 + Math.min(ctx.streak, 10) * 0.03);
  const reps = ctx.dayActs.filter(e => e.cat === cat && e.xp > 0).length;
  if (reps > 0) mul(`Повтор · ${reps + 1}-й раз за день`, Math.pow(0.85, reps));
  const cal = ctx.cal[cat] ?? 1;
  if (Math.abs(cal - 1) > 0.001) mul('Твоя калибровка', cal);
  xp = Math.round(xp);
  if (!ctx.dayActs.some(e => e.xp > 0)) { xp += 10; steps.push({ name: 'Первое дело за день', val: '+10' }); }
  return { cat, xp, steps, sure: cat !== 'misc' };
}

/* ---------- уровни ---------- */
const lvlReq = L => Math.round(100 * Math.pow(L, 1.4));
const skillReq = L => Math.round(60 * Math.pow(L, 1.3));
function levelInfo(total, req = lvlReq) {
  let level = 1, start = 0;
  while (total - start >= req(level)) { start += req(level); level++; }
  const need = req(level), into = total - start;
  return { level, start, into, need, p: into / need };
}
const RANKS = [[20, 'Легенда'], [15, 'Мастер'], [10, 'Практик'], [5, 'Ученик'], [1, 'Новичок']];
const rankOf = L => RANKS.find(([min]) => L >= min)[1];


export { assess, quantities, detectCat, levelInfo, lvlReq, skillReq, rankOf, CATS, SKILLS };
