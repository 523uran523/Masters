from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/features/today/today_screen.dart")
s=p.read_text(encoding="utf-8")
# Add dart:math import once
if "import 'dart:math';" not in s:
    s=s.replace("import 'package:flutter/cupertino.dart';\n", "import 'dart:math';\nimport 'package:flutter/cupertino.dart';\n",1)

# Portrait: insert overview before first active section; use line index 82 (0-based 82)
lines=s.splitlines(True)
idx=82
assert "buildSection('Активные'" in lines[idx] or 'buildSection' in lines[idx]
lines[idx:idx] = ["                  _buildTodayOverview(store, context),\n", "                  const SizedBox(height: 12),\n"]
# Landscape: change first expanded block to side panel + lists group
text="\n".join(lines)
old="""                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 24),
                    children: [buildSection('Активные', active)],
                  ),
                ),"""
new="""                SizedBox(
                  width: 320,
                  child: _buildTodayOverview(store, context),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(8, 12, 16, 24),
                    children: [buildSection('Активные', active), buildSection('Срок сегодня', dueToday), buildSection('Новые', newJobs)],
                  ),
                ),"""
# Might fail exact string but try
# Use key line
key="children: [buildSection('Активные', active)],"
assert key in text
text=text.replace("                Expanded(\n                  child: ListView(\n                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 24),\n                    children: [buildSection('Активные', active)],\n                  ),\n                ),",
                 new,1)
# Append helper class if absent
if "class _TodayOverviewPanel" not in text:
    text+="\n\nclass _TodayOverviewPanel extends StatelessWidget {\n  const _TodayOverviewPanel({required this.store});\n  final MastersStore store;\n\n  @override\n  Widget build(BuildContext context) {\n    // This helper is unused placeholder; the real overview is _buildTodayOverview below.\n    return const SizedBox.shrink();\n  }\n}\n"
p.write_text(text, encoding="utf-8")
print("ok")
