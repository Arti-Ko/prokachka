// Пишет в код обеих платформ каталог достижений и словарь формулы. Запуск: node spec/reference/gen-code.mjs
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ACHIEVEMENTS } from './achievements.mjs';

const root = new URL('../../', import.meta.url);
const q = s => JSON.stringify(s);
const write = (rel, text) => {
  const url = new URL(rel, root);
  mkdirSync(dirname(fileURLToPath(url)), { recursive: true });
  writeFileSync(url, text);
};

write('spec/achievements.json', JSON.stringify(ACHIEVEMENTS, null, 1) + '\n');

write('mac/Sources/ProkachkaCore/AchievementCatalog.swift', `// Сгенерировано spec/reference/gen-code.mjs — не править руками.

public enum AchievementCatalog {
    public static let all: [AchievementDef] = [
${ACHIEVEMENTS.map(x => `        AchievementDef(id: ${q(x.id)}, group: ${q(x.group)}, metric: ${q(x.metric)}, goal: ${x.goal}, tier: ${x.tier}, title: ${q(x.title)}, text: ${q(x.text)}, hidden: ${x.hidden}),`).join('\n')}
    ]
}
`);

write('android/app/src/main/java/dev/artiko/prokachka/core/AchievementCatalog.kt', `// Сгенерировано spec/reference/gen-code.mjs — не править руками.
package dev.artiko.prokachka.core

object AchievementCatalog {
    val all: List<AchievementDef> = listOf(
${ACHIEVEMENTS.map(x => `        AchievementDef(${q(x.id)}, ${q(x.group)}, ${q(x.metric)}, ${x.goal}, ${x.tier}, ${q(x.title)}, ${q(x.text)}, ${x.hidden}),`).join('\n')}
    )
}
`);
console.log(`достижений: ${ACHIEVEMENTS.length}`);

/* ---------- словарь формулы ---------- */
import { CUES, MINUS, ABSTAIN, NEGATED, PLAN, PAST, SELF, HELPED, RECORD, HARD, EASY, INTENSE, SLEEP, DISTANCE, NUMBER_WORDS } from './engine.mjs';

for (const re of [ABSTAIN, NEGATED, PLAN, PAST, SELF, HELPED, RECORD, HARD, EASY, INTENSE, SLEEP, ...CUES.map(c => c[2]), ...MINUS.map(m => m.re)]) {
  if (re.source.includes('"#') || re.source.includes('"""') || re.source.includes('$')) throw new Error(`шаблон не влезет в сырую строку: ${re.source}`);
}
const sw = re => `Rx(#"${re.source}"#)`;
const kt = re => `Rx("""${re.source}""")`;

write('mac/Sources/ProkachkaCore/Rules.swift', `// Сгенерировано spec/reference/gen-code.mjs из spec/reference/engine.mjs — не править руками.

enum Rules {
    static let cues: [(Skill, Int, Rx)] = [
${CUES.map(([c, w, re]) => `        (.${c}, ${w}, ${sw(re)}),`).join('\n')}
    ]

    static let minuses: [Minus] = [
${MINUS.map(m => `        Minus(rx: ${sw(m.re)}, xp: ${m.xp}, skill: .${m.cat}, label: ${q(m.label)}${m.perHour ? ', perHour: true' : ''}),`).join('\n')}
    ]

    static let abstain = ${sw(ABSTAIN)}
    static let negated = ${sw(NEGATED)}
    static let plan = ${sw(PLAN)}
    static let past = ${sw(PAST)}
    static let selfMade = ${sw(SELF)}
    static let helped = ${sw(HELPED)}
    static let record = ${sw(RECORD)}
    static let hard = ${sw(HARD)}
    static let easy = ${sw(EASY)}
    static let intense = ${sw(INTENSE)}
    static let sleep = ${sw(SLEEP)}
    static let distance: [(Rx, Double)] = [
${DISTANCE.map(([re, km]) => `        (${sw(re)}, ${km}),`).join('\n')}
    ]
    static let numberWords: [String: Double] = [
${Object.entries(NUMBER_WORDS).map(([w, v]) => `        ${q(w)}: ${v},`).join('\n')}
    ]
}
`);

write('android/app/src/main/java/dev/artiko/prokachka/core/Rules.kt', `// Сгенерировано spec/reference/gen-code.mjs из spec/reference/engine.mjs — не править руками.
package dev.artiko.prokachka.core

internal object Rules {
    val cues: List<Triple<Skill, Int, Rx>> = listOf(
${CUES.map(([c, w, re]) => `        Triple(Skill.${c.toUpperCase()}, ${w}, ${kt(re)}),`).join('\n')}
    )

    val minuses: List<Minus> = listOf(
${MINUS.map(m => `        Minus(${kt(m.re)}, ${m.xp}.0, Skill.${m.cat.toUpperCase()}, ${q(m.label)}${m.perHour ? ', perHour = true' : ''}),`).join('\n')}
    )

    val abstain = ${kt(ABSTAIN)}
    val negated = ${kt(NEGATED)}
    val plan = ${kt(PLAN)}
    val past = ${kt(PAST)}
    val selfMade = ${kt(SELF)}
    val helped = ${kt(HELPED)}
    val record = ${kt(RECORD)}
    val hard = ${kt(HARD)}
    val easy = ${kt(EASY)}
    val intense = ${kt(INTENSE)}
    val sleep = ${kt(SLEEP)}
    val distance: List<Pair<Rx, Double>> = listOf(
${DISTANCE.map(([re, km]) => `        ${kt(re)} to ${Number.isInteger(km) ? km + '.0' : km},`).join('\n')}
    )
    val numberWords: Map<String, Double> = mapOf(
${Object.entries(NUMBER_WORDS).map(([w, v]) => `        ${q(w)} to ${Number.isInteger(v) ? v + '.0' : v},`).join('\n')}
    )
}
`);
console.log('словарь записан');
