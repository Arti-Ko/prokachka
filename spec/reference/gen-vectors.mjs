// Генерирует spec/vectors/*.json из эталона. Запуск: node spec/reference/gen-vectors.mjs
import { writeFileSync } from 'node:fs';
import { assess, hint, levelInfo, skillReq, prepare } from './engine.mjs';

const act = (cat, xp, text, label) => ({ cat, xp, text: prepare(text), label: label ?? (xp < 0 ? '' : '') });
const CONTEXTS = {
  fresh: { dayActs: [], streak: 0, cal: {}, lastTrained: {}, daysSinceAny: null },
  busy: {
    dayActs: [act('body', 53, 'Пробежал 5 км', 'База · Тело'), act('work', 94, 'Написал ТЗ', 'База · Дело')],
    streak: 7, cal: {}, lastTrained: { body: 1, mind: 4, work: 1, home: 2, people: 10, rest: 1 }, daysSinceAny: 1,
  },
  tuned: {
    dayActs: [act('work', 94, 'Закрыл 3 задачи', 'База · Дело'), act('work', 50, 'Созвон', 'База · Дело'), act('rest', -20, 'Залип в тиктоке 2 часа', 'Залип в ленте')],
    streak: 3, cal: { work: 1.1, body: 0.9 }, lastTrained: { body: 1, mind: 1, work: 1, home: 1, people: 1, craft: 1, rest: 1 }, daysSinceAny: 1,
  },
  long: { dayActs: [act('mind', -5, 'Забыл', 'Не сделал')], streak: 25, cal: { mind: 1.21 }, lastTrained: { body: 2, mind: 1, work: 1, craft: 7 }, daysSinceAny: 1 },
  comeback: { dayActs: [], streak: 0, cal: {}, lastTrained: { body: 5, work: 4, mind: 9 }, daysSinceAny: 4 },
  tired: { dayActs: [act('work', 300, 'Работал весь день', 'База · Дело'), act('body', 300, 'Марафон', 'База · Тело')], streak: 2, cal: {}, lastTrained: { body: 1, work: 1 }, daysSinceAny: 1 },
  exhausted: { dayActs: [act('work', 500, 'Аврал', 'База · Дело'), act('craft', 400, 'Клип', 'База · Творчество')], streak: 2, cal: {}, lastTrained: {}, daysSinceAny: 1 },
  again: {
    dayActs: [act('body', 62, 'Пробежал 5 км', 'База · Тело'), act('rest', -25, 'Курил', 'Курение'), act('rest', -38, 'Курил', 'Курение')],
    streak: 4, cal: {}, lastTrained: { body: 1 }, daysSinceAny: 1,
  },
};
const PHRASES = [
  // старые
  'Сам написал алгоритм начисления опыта за 2 часа', 'Пробежал 5 км', 'Пробежал 2,5 км за 20 минут', 'Впервые подтянулся 10 раз',
  'Сделал 50 отжиманий', 'Прочитал 30 страниц', 'Прочёл книгу за 3 часа', 'Сделал ТЗ по туториалу', 'Закрыл 3 задачи',
  'Написал ТЗ на экран профиля, 1,5 часа', '2 часа 30 минут кодил', 'Починил баг в проде, сложный', 'Созвон с клиентом полчаса',
  'Помыл посуду быстро', 'Убрался в квартире весь день', 'Приготовил ужин', 'Позвонил маме', 'Помог другу с переездом',
  'Нарисовал скетч', 'Смонтировал видео 4 часа', 'Написал пост', 'Медитировал 10 минут', 'Выпил 2 литра воды',
  'Выучил 40 слов английского', 'Йога 45 мин', 'Проспал до обеда', 'Пропустил тренировку', 'Залип в тиктоке 2 часа',
  'Залип в соцсетях на 10 часов', 'Курил', 'Выпил пива', 'Съел бургер', 'Прокрастинировал', 'Сорвался на брата',
  'Опоздал на встречу', 'Лёг в 3 ночи', 'Забыл позвонить', 'Не курил весь день', 'Без сахара', 'Посмотрел на закат',
  'Сделал с помощью ChatGPT презентацию', 'Наконец сдал экзамен', 'Немного погулял', 'ok', '12', '  ', 'Сделал что-то',
  // числа словами и новые меры
  'Пробежал пять километров', 'Читал два часа', 'Двадцать пять отжиманий', 'Полтора часа делал отчёт', 'Медитировал пол часа',
  'Сделал 3 подхода по 20 раз', 'Проехал 20 км на велосипеде', 'Проплыл 800 м в бассейне', 'Прошёл 12000 шагов', 'Гулял 6 км пешком',
  'Прочитал 2 главы', '1ч30м занимался английским', 'Работал весь вечер', 'Тренировка до отказа', 'Поставил личный рекорд в жиме',
  'Решил 3 задачи на литкоде', 'Разобрал шкаф', 'Сам разобрался с BPMN-диаграммой', 'Созвонился с мамой', 'Поужинал с семьёй',
  'Спал 8 часов', 'Сходил в сауну', 'Полил цветы', 'Сыграл в шахматы', 'Отправил отчёт клиенту, 3 часа',
  // отрицания, планы, отказы
  'Не пошёл в зал', 'Не сделала зарядку', 'Не позвонил маме', 'Не пропустил ни одной тренировки', 'Отказался от сладкого',
  'Завтра пойду в зал', 'Хочу выучить английский', 'Надо было сходить в магазин', 'Сделал всё, что надо', 'Импульсивная покупка',
  'Прогулял пару', 'Курил', 'Пробежал 5 км',
];
const cases = [];
for (const [name, ctx] of Object.entries(CONTEXTS)) {
  for (const text of PHRASES) cases.push({ text, context: name, expect: assess(text, ctx) });
}
for (const text of ['Посмотрел на закат', 'Сделал что-то', 'Пробежал 5 км']) {
  for (const override of ['craft', 'people']) cases.push({ text, context: 'busy', override, expect: assess(text, { ...CONTEXTS.busy, override }) });
}
const hints = ['', 'ok', '12', 'Завтра пойду в зал', 'Хочу выучить английский', 'Пробежал 5 км', 'Сделал всё, что надо'].map(text => ({ text, hint: hint(text) }));
const prepared = ['Двадцать пять отжиманий', 'Пробежал пять километров', 'Медитировал пол часа', 'Полтора часа', 'Сто двадцать страниц', 'Семья и семь дней']
  .map(text => ({ text, prepared: prepare(text) }));
writeFileSync(new URL('../vectors/assess.json', import.meta.url), JSON.stringify({ contexts: CONTEXTS, cases, hints, prepared }, null, 1) + '\n');

const totals = [0, 1, 99, 100, 101, 263, 364, 365, 5000, 14623, 14624, 17300, 250000];
const levels = totals.map(total => ({ total, level: levelInfo(total), skill: levelInfo(total, skillReq) }));
writeFileSync(new URL('../vectors/levels.json', import.meta.url), JSON.stringify(levels, null, 1) + '\n');
console.log(`assess: ${cases.length}, hints: ${hints.length}, levels: ${levels.length}`);
