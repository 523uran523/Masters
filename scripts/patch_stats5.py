from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/features/stats/stats_screen.dart")
s=p.read_text(encoding="utf-8")
anchor = "    final sortedClients = topClients.entries.toList()..sort((a, b) => b.value.compareTo(a.value));\n"
addition = anchor + """
    final staffRevenue = <String, int>{};
    for (final j in completedJobs) {
      final key = j.assigneeId ?? 'unassigned';
      staffRevenue[key] = (staffRevenue[key] ?? 0) + j.priceCents;
    }
    final sortedStaff = staffRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
"""
assert anchor in s
s=s.replace(anchor, addition, 1)

# insert employee stats before 'Top clients' section.
needle = "            SectionLabel('\u0422\u043e\u043f \u043a\u043b\u0438\u0435\u043d\u0442\u044b'),\n"
block = (
    "            const SizedBox(height: 16),\n"
    "            SectionLabel('\u041f\u043e \u0441\u043e\u0442\u0440\u0443\u0434\u043d\u0438\u043a\u0430\u043c'),\n"
    "            AppCard(\n"
    "              child: sortedStaff.isEmpty\n"
    "                  ? EmptyState(\n"
    "                      title: '\u041d\u0435\u0442 \u0434\u0430\u043d\u043d\u044b\u0445',\n"
    "                      message: '\u0417\u0434\u0435\u0441\u044c \u043f\u043e\u044f\u0432\u0438\u0442\u0441\u044f \u0440\u0430\u0437\u0431\u043e\u0440 \u043f\u043e \u0438\u0441\u043f\u043e\u043b\u043d\u0438\u0442\u0435\u043b\u044f\u043c.',\n"
    "                      art: Icon(CupertinoIcons.person_2, size: 36, color: colors.tertiaryLabel),\n"
    "                    )\n"
    "                  : Column(\n"
    "                      children: sortedStaff.map((e) {\n"
    "                        final name = e.key == 'unassigned'\n"
    "                            ? '\\u0431\u0435\u0437 \\u0438\\u0441\u043f\u043e\\u043b\u043d\\u0438\\u0442\u0435\u043b\u044f'\n"
    "                            : store.employeeById(e.key)?.name ?? e.key;\n"
    "                        return Padding(\n"
    "                          padding: const EdgeInsets.symmetric(vertical: 6),\n"
    "                          child: Row(\n"
    "                            mainAxisAlignment: MainAxisAlignment.spaceBetween,\n"
    "                            children: [\n"
    "                              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w500))),\n"
    "                              Text(_money(e.value), style: const TextStyle(fontWeight: FontWeight.w600)),\n"
    "                            ],\n"
    "                          ),\n"
    "                        );\n"
    "                      }).toList(),\n"
    "                    ),\n"
    "            ),\n"
    "            const SizedBox(height: 16),\n"
)
assert needle in s
s = s.replace(needle, block + needle, 1)
p.write_text(s, encoding="utf-8")
print("done")
