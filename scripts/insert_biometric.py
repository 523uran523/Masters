from pathlib import Path
p = Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/features/settings/settings_screen.dart")
lines = p.read_text(encoding="utf-8").splitlines(True)
anchor = "                      SecondaryButton(\n                        label: "
assert any("onPressed: _managePin," in l for l in lines)
start = next(i for i, l in enumerate(lines) if "onPressed: _managePin," in l)
# insert after the closing "), " of the SecondaryButton (next non-empty after target)
insert_at = start + 1
while insert_at < len(lines) and lines[insert_at].strip() == "":
    insert_at += 1
assert lines[insert_at].strip() == "),", lines[insert_at].strip()
insert_at += 1
block = (
    "                      const SizedBox(height: 8),\n"
    "                      FutureBuilder<bool>(\n"
    "                        future: AppBiometricService.isAvailable(),\n"
    "                        builder: (context, snapshot) {\n"
    "                          final available = snapshot.data ?? false;\n"
    "                          if (!available) return const SizedBox.shrink();\n"
    "                          return Row(\n"
    "                            children: [\n"
    "                              const Expanded(child: Text('Биометрия (разблокировка)')),\n"
    "                              CupertinoSwitch(\n"
    "                                value: settings.biometricEnabled,\n"
    "                                onChanged: (v) async {\n"
    "                                  await context.read<SettingsController>().setBiometricEnabled(v);\n"
    "                                  if (!context.mounted) return;\n"
    "                                  setState(() {});\n"
    "                                },\n"
    "                              ),\n"
    "                            ],\n"
    "                          );\n"
    "                        },\n"
    "                      ),\n"
)
lines.insert(insert_at, block)
p.write_text("".join(lines), encoding="utf-8")
print("done")
