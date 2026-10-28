from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib\state\masters_store.dart")
s=p.read_text(encoding="utf-8")
marker="  Future<void> clearAll() async {\n"
meth="""  /// App-level integrity check, used on web where FK enforcement is off.
  Future<List<String>> checkDataIntegrity() async {
    return _appDatabase.integrityIssues();
  }

"""
assert marker in s
s=s.replace(marker, meth+marker,1)
p.write_text(s, encoding="utf-8")
print("done")
