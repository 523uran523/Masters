from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib\app\app.dart")
lines=p.read_text(encoding="utf-8").splitlines(True)
# find index of line "          actions: ["
for i,l in enumerate(lines):
    if l.strip()=="actions: [":
        # replace line i-1 and maybe i-2 if content Text line
        lines[i-1] = "          content: const Text('В облаке новее резервная копия. Заменить локальные данные?'),\n"
        # remove line i-2 if it is the continuation broken string line
        if i>=2 and "content: Text(" in lines[i-2]:
            del lines[i-2]
        print("done", i+1)
        break
else:
    print("not found")
p.write_text("".join(lines), encoding="utf-8")
