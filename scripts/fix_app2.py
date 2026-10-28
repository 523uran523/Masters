from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib\app\app.dart")
lines=p.read_text(encoding="utf-8").splitlines(True)
for i,line in enumerate(lines,1):
    if "remote.modified.toLocal()" in line:
        lines[i-1] = "              'В облаке найдена более новая резервная копия от ${remote.modified.toLocal()}. '\n"
        # preserve what's next? The next line already continues maybe blank.
        # ensure the following line not duplicated suffix
        print("fixed", i, repr(lines[i-1]))
p.write_text("".join(lines), encoding="utf-8")
