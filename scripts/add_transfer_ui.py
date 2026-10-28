from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/features/money/money_screen.dart")
s=p.read_text(encoding="utf-8")
anchor="  Future<void> _newAccount() async {\n"
method='''  Future<void> _transferBetweenAccounts() async {
    final store = context.read<MastersStore>();
    final accounts = store.accounts.where((a) => !a.archived).toList();
    if (accounts.length < 2) {
      if (!mounted) return;
      await showAppAlert(context,
          title: 'Перевод', message: 'Нужно минимум 2 счёта.');
      return;
    }
    final amountStr = await _prompt('Сумма перевода', '0');
    if (amountStr == null) return;
    final amount = ((double.tryParse(amountStr.replaceAll(',', '.')) ?? 0) * 100).round();
    if (amount <= 0) return;

    final fromId = await _pickAccountExcluding(null);
    if (fromId == null || !mounted) return;
    final toId = await _pickAccountExcluding(fromId);
    if (toId == null || !mounted) return;
    final note = await _prompt('Комментарий', '');

    setState(() => _busy = true);
    try {
      await store.transferBetweenAccounts(fromId, toId, amount, note: note);
    } catch (e) {
      if (mounted) {
        await showAppAlert(context, title: 'Ошибка', message: e.toString());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _pickAccountExcluding(String? excludedId) async {
    final store = context.read<MastersStore>();
    final accounts = store.accounts
        .where((a) => !a.archived && a.id != excludedId)
        .toList();
    return showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => Container(
        height: 320,
        color: context.colors.card,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                    child: const Text('Отмена'),
                    onPressed: () => Navigator.of(ctx).pop()),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final a in accounts)
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(a.id),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(a.name),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

'''
assert anchor in s
s = s.replace(anchor, method + anchor, 1)
p.write_text(s, encoding="utf-8")
print("done")
