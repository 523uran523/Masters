from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/state/masters_store.dart")
s=p.read_text(encoding="utf-8")
old = """    if (cashTypes.contains(type)) {
      final account = _accounts.firstWhere(
        (a) => !a.archived,
        orElse: () => _accounts.isNotEmpty ? _accounts.first : _accounts.first,
      ); // ensure non-empty list
      if (_accounts.isNotEmpty) {"""
new = """    if (cashTypes.contains(type) && _accounts.isNotEmpty) {
      final account = _accounts.firstWhere(
        (a) => !a.archived,
        orElse: () => _accounts.first,
      );"""
assert old in s
s=s.replace(old,new)
p.write_text(s, encoding="utf-8")
print("done")
