// Генерирует spec/vectors/*.json из эталона. Запуск: node spec/reference/gen-vectors.mjs
import { writeFileSync } from 'node:fs';
import { assess, levelInfo, skillReq } from './engine.mjs';

const CONTEXTS = {
  fresh: { dayActs: [], streak: 0, cal: {} },
  busy: { dayActs: [{ cat: 'body', xp: 53 }, { cat: 'work', xp: 94 }], streak: 7, cal: {} },
  tuned: { dayActs: [{ cat: 'work', xp: 94 }, { cat: 'work', xp: 50 }, { cat: 'rest', xp: -20 }], streak: 3, cal: { work: 1.1, body: 0.9 } },
  long: { dayActs: [{ cat: 'mind', xp: -5 }], streak: 14, cal: { mind: 1.21 } },
};
const PHRASES = [
  'Сам написал алгоритм начисления опыта за 2 часа', 'Пробежал 5 км', 'Пробежал 2,5 км за 20 минут', 'Впервые подтянулся 10 раз',
  'Сделал 50 отжиманий', 'Прочитал 30 страниц', 'Прочёл книгу за 3 часа', 'Сделал ТЗ по туториалу', 'Закрыл 3 задачи',
  'Написал ТЗ на экран профиля, 1,5 часа', '2 часа 30 минут кодил', 'Починил баг в проде, сложный', 'Созвон с клиентом полчаса',
  'Помыл посуду быстро', 'Убрался в квартире весь день', 'Приготовил ужин', 'Позвонил маме', 'Помог другу с переездом',
  'Нарисовал скетч', 'Смонтировал видео 4 часа', 'Написал пост', 'Медитировал 10 минут', 'Выпил 2 литра воды',
  'Выучил 40 слов английского', 'Йога 45 мин', 'Проспал до обеда', 'Пропустил тренировку', 'Залип в тиктоке 2 часа',
  'Залип в соцсетях на 10 часов', 'Курил', 'Выпил пива', 'Съел бургер', 'Прокрастинировал', 'Сорвался на брата',
  'Опоздал на встречу', 'Лёг в 3 ночи', 'Забыл позвонить', 'Не курил весь день', 'Без сахара', 'Посмотрел на закат',
  'Сделал с помощью ChatGPT презентацию', 'Наконец сдал экзамен', 'Немного погулял', 'ok', '12', '  ', 'Сделал что-то',
];
const assessCases = [];
for (const [name, ctx] of Object.entries(CONTEXTS)) {
  for (const text of PHRASES) assessCases.push({ text, context: name, expect: assess(text, ctx) });
}
for (const text of ['Посмотрел на закат', 'Сделал что-то', 'Пробежал 5 км']) {
  for (const override of ['craft', 'people']) assessCases.push({ text, context: 'busy', override, expect: assess(text, { ...CONTEXTS.busy, override }) });
}
writeFileSync(new URL('../vectors/assess.json', import.meta.url), JSON.stringify({ contexts: CONTEXTS, cases: assessCases }, null, 1) + '\n');

const totals = [0, 1, 99, 100, 101, 263, 364, 365, 5000, 14623, 14624, 17300, 250000];
const levels = totals.map(total => ({ total, level: levelInfo(total), skill: levelInfo(total, skillReq) }));
writeFileSync(new URL('../vectors/levels.json', import.meta.url), JSON.stringify(levels, null, 1) + '\n');
console.log(`assess: ${assessCases.length}, levels: ${levels.length}`);
