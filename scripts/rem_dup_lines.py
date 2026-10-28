from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib\data\app_database.dart")
lines = p.read_text(encoding="utf-8").splitlines(True)
# remove duplicate method lines 409..434 (1-based)
del lines[408:434]  # indices for 409..434
p.write_text("".join(lines), encoding="utf-8")
print("done")
