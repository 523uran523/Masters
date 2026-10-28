from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/features/today/today_screen.dart")
lines=p.read_text(encoding="utf-8").splitlines(True)
# find first occurrence of _buildTodayOverview line, ensure previous line has padding + children missing
if (lines[83].strip().startswith('_buildTodayOverview') and "children: [" not in lines[82]):
    lines[82] = "                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),\n"  # ensure same
    lines.insert(83, "                children: [\n")
p.write_text("".join(lines), encoding="utf-8")
print("done")
