from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib\features\settings\settings_screen.dart")
s=p.read_text(encoding="utf-8")
marker="  Future<void> _clearData() async {\n"
meth="""  Future<void> _checkDataIntegrity() async {
    final issues = await context.read<MastersStore>().checkDataIntegrity();
    if (!mounted) return;
    await showAppAlert(
      context,
      title: issues.isEmpty ? '\\u041fроверка завершена' : 'Нарушения целостности',
      message: issues.isEmpty
          ? 'Нарушений не найдено.'
          : issues.join('\\n'),
    );
  }

"""
assert marker in s
s=s.replace(marker, meth+marker, 1)
p.write_text(s, encoding="utf-8")
print("done")
