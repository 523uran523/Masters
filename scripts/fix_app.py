from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib\app\app.dart")
s=p.read_text(encoding="utf-8")
s=s.replace("'В облаке newer бэкап от ${remote.modified.toLocal()}. ", "'В облаке найдена более новая резервная копия от ${remote.modified.toLocal()}. ")
# fallback if mojibake
for line in s.splitlines():
    pass
p.write_text(s, encoding="utf-8")
print('done')
