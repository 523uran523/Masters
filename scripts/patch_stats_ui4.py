from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/features/stats/stats_screen.dart")
lines=p.read_text(encoding="utf-8").splitlines(True)
# line 153 (1-based) is the AppCard closing, before ListView children close.
assert lines[152].strip() == "),", repr(lines[152])
block = "\n".join([
"            ),",
"            const SizedBox(height: 16),",
"            SectionLabel('По сотрудникам'),",
"            AppCard(",
"              child: sortedStaff.isEmpty",
"                  ? EmptyState(title: 'Нет данных', message: 'Здесь появится разбор по исполнителям.', art: Icon(CupertinoIcons.person_2, size: 36, color: colors.tertiaryLabel))",
"                  : Column(",
"                      children: sortedStaff.map((e) {",
"                        final name = e.key == 'unassigned'",
"                            ? 'Без исполнителя'",
"                            : store.employeeById(e.key)?.name ?? e.key;",
"                        return Padding(",
"                          padding: const EdgeInsets.symmetric(vertical: 6),",
"                          child: Row(",
"                            mainAxisAlignment: MainAxisAlignment.spaceBetween,",
"                            children: [",
"                              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500))),",
"                              Text(_money(e.value), style: const TextStyle(fontWeight: FontWeight.w600)),",
"                            ],",
"                          ),",
"                        );",
"                      }).toList(),",
"                    ),",
"            ),",
]) + "\n"
# replace line 153 only with new block
lines[152:153] = [block]
p.write_text("".join(lines), encoding="utf-8")
print("done")
