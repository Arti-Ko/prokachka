"""Вырезает формулу из design/prototype.html в spec/reference/engine.mjs.

Запуск из корня репозитория: python3 spec/reference/extract.py && node spec/reference/gen-vectors.mjs
"""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
html = (root / "design/prototype.html").read_text(encoding="utf-8")
start = html.index("const esc = ")
end = html.index("/* ---------- примерная история ---------- */")
head = (
    "// Эталон формулы опыта. Вырезан из design/prototype.html — по нему сверяются Swift и Kotlin.\n"
    "// Не править руками: при изменении формулы правится прототип и пересобираются векторы.\n"
)
tail = "\nexport { assess, quantities, detectCat, levelInfo, lvlReq, skillReq, rankOf, CATS, SKILLS };\n"
(root / "spec/reference/engine.mjs").write_text(head + html[start:end] + tail, encoding="utf-8")
print("engine.mjs обновлён")
