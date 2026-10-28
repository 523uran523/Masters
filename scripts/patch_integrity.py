from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib\features\settings\settings_screen.dart")
s=p.read_text(encoding="utf-8")
marker = "                        onTap: _clearData,\n                      ),\n"
assert marker in s
insertion = marker + "                      Hairline(indent: 0),\n" + "                      _ActionTile(\n" + "                        icon: CupertinoIcons.shield_fill,\n" + "                        label: 'Проверить целостность данных',\n" + "                        onTap: _checkDataIntegrity,\n" + "                      ),\n"
s = s.replace(marker, insertion, 1)
p.write_text(s, encoding="utf-8")
print("done")
