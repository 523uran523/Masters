from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/core/single_tab_coordinator_web.dart")
s=p.read_text(encoding="utf-8")
s=s.replace("jsifyValueStrict()", "jsify()", 2)
p.write_text(s, encoding="utf-8")
print("done")
