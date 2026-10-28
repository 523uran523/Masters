from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/features/money/money_screen.dart")
lines=p.read_text(encoding="utf-8").splitlines(True)
anchor = lines[357]  # 0-based 357 = line 358 "  const SizedBox(height: 16),"
assert anchor.strip() == "const SizedBox(height: 16),", anchor.strip()
block = """                  const SizedBox(height: 8),
                  SecondaryButton(label: 'Перевод между счетами', icon: CupertinoIcons.arrow_left_right, onPressed: _transferBetweenAccounts),
                  const SizedBox(height: 16),
                  SectionLabel('Команда'),
                  ..._buildTeamSection(store, colors),
                  const SizedBox(height: 12),
"""
# Must be one string; line insert after 357
lines.insert(358, block)
p.write_text("".join(lines), encoding="utf-8")
print("done")
