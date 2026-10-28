from pathlib import Path
txt=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/state/masters_store.dart").read_text(encoding="utf-8")
brace=0
for ch in txt:
    if ch == "{":
        brace += 1
    elif ch == "}":
        brace -= 1
print("brace balance:", brace)
print("num lines:", txt.count("\n"))
