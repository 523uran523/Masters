from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib\data\app_database.dart")
s=p.read_text(encoding="utf-8")
needle="  Future<void> close() => database.close();\n\n  /// App-level integrity check"
idx=s.find(needle)
assert idx!=-1
# end second method: find "  Future<void> close()" first occurrence before idx? Actually first close method occurs after first integrity method. We want remove second integrity method (from marker at line 382?).
# Remove from marker starting second comment, keep up to closing of second method.
needle2="  /// App-level integrity check used especially"
i2=s.index(needle2)
# find end marker after i2 before final
end=s.index("  Future<void> close() => database.close();", i2)
# Remove between method start and end close, but keep one close.
s=s[:i2] + "  Future<void> close() => database.close();\n" + s[end+len("  Future<void> close() => database.close();"):]
p.write_text(s, encoding="utf-8")
print("done")
