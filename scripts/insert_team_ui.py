from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/features/money/money_screen.dart")
lines=p.read_text(encoding="utf-8").splitlines(True)
idx = 443  # 0-based index of debt SectionLabel? line 444 -> index 443
assert 'SectionLabel' in lines[idx]
# avoid double insert: check previous line
if 'Команда' not in lines[idx-1]:
    block = """                  const SizedBox(height: 8),
                  SectionLabel('Команда'),
                  ..._teamCards(store, colors),
                  const SizedBox(height: 16),
"""
    lines.insert(idx, block)
p.write_text("".join(lines), encoding="utf-8")
print("done")
