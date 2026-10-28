from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/features/settings/settings_screen.dart")
s=p.read_text(encoding="utf-8")
anchor="  Future<void> _clearData() async {\n"
meth='''  Future<void> _showAuditLog() async {
    final entries = await context.read<MastersStore>().auditEntries(limit: 50);
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Журнал действий'),
        content: SizedBox(
          height: 300,
          width: 340,
          child: entries.isEmpty
              ? const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Записей пока нет.'),
                )
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) {
                    final row = entries[i];
                    final at = DateTime.fromMillisecondsSinceEpoch((row['at'] as int?) ?? 0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${row['action']} ? ${row['entity']} ${row['entity_id'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          Text(
                            '${at.toLocal()}  '
                            '${row['before_json'] ?? ''} -> ${row['after_json'] ?? ''}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

'''
assert anchor in s
s=s.replace(anchor, meth+anchor,1)
p.write_text(s,encoding="utf-8")
print("done")
