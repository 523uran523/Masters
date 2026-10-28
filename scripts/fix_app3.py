from pathlib import Path
import re
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib\app\app.dart")
s=p.read_text(encoding="utf-8")
pat=re.compile(r"          content: Text\(\n(?:.*\n)*?          actions: \[", re.DOTALL)
new_block = """          content: const Text('В облаке найдена более новая резервная копия. Заменить локальные данные?'),
          actions: ["""
s2, n = pat.subn(new_block, s, count=1)
print("replaced", n)
p.write_text(s2, encoding="utf-8")
