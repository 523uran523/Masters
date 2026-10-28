from pathlib import Path
txt=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/state/masters_store.dart").read_text(encoding="utf-8").splitlines(True)
brace=0
prev=0
for i,line in enumerate(txt,1):
    brace += line.count("{") - line.count("}")
    # only lines where balance changes drastically
    if abs((line.count("{")-line.count("}"))) > 1:
        pass
# print transitions to <=0 around 950-1120
bal=0
for i,line in enumerate(txt,1):
    bal += line.count("{") - line.count("}")
    if 950 < i < 1120 and bal <= 1:
        print(i, bal, repr(line.strip()))
