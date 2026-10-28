from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/features/money/money_screen.dart")
lines=p.read_text(encoding="utf-8").splitlines(True)
# insert after line 321 (0-based index 320), which is "                  ),"
anchor = lines[320]
assert anchor.strip() == ")," , anchor.strip()
ins = """                  const SizedBox(height: 8),
                  SecondaryButton(label: 'Перевод между счетами', icon: CupertinoIcons.arrow_left_right, onPressed: _transferBetweenAccounts),
"""
lines.insert(321, ins)
p.write_text("".join(lines), encoding="utf-8")
print("done")
