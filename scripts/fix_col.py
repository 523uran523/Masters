import re
from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/state/masters_store.dart")
s=p.read_text(encoding="utf-8")
s=s.replace("static int _col(List<String> header, String... names) {",
            "static int _col(List<String> header, List<String> names) {")
# convert calls _col(header, 'a', 'b'...) -> _col(header, ['a', 'b'...])
s = re.sub(r"_col\(\s*header\s*,\s*((?:'[^']*'\s*,?\s*)+)\)", lambda m: "_col(header, [" + ", ".join(v.strip() for v in m.group(1).split(",") if v.strip()) + "])", s)
p.write_text(s, encoding="utf-8")
print("done")
