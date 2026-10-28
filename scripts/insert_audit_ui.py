from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/features/settings/settings_screen.dart")
s=p.read_text(encoding="utf-8")
anchor = '''                      _ActionTile(
                        icon: CupertinoIcons.cloud_download,
                        label: 'Экспорт JSON',
                        onTap: _exportBackup,
                      ),'''
assert anchor in s
block = '''                      _ActionTile(
                        icon: CupertinoIcons.list_bullet,
                        label: 'Журнал действий',
                        onTap: _showAuditLog,
                      ),
                      Hairline(indent: 0),
                      _ActionTile(
                        icon: CupertinoIcons.cloud_download,
                        label: 'Экспорт JSON',
                        onTap: _exportBackup,
                      ),'''
s=s.replace(anchor, block, 1)
p.write_text(s, encoding="utf-8")
print("done")
