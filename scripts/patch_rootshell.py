from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib/app/root_shell.dart")
s=p.read_text(encoding="utf-8")
old = "  @override\n  Widget build(BuildContext context) {\n    final colors = context.colors;\n    final settings = context.watch<SettingsController>();\n"
new = ("  @override\n"
       "  void initState() {\n"
       "    super.initState();\n"
       "    BrowserTabCoordinator.instance.addListener(() {\n"
       "      if (mounted) setState(() {});\n"
       "    });\n"
       "    if (kIsWeb) BrowserTabCoordinator.instance.start();\n"
       "  }\n\n"
       "  @override\n"
       "  void dispose() {\n"
       "    BrowserTabCoordinator.instance.removeListener(() {\n"
       "      if (mounted) setState(() {});\n"
       "    });\n"
       "    super.dispose();\n"
       "  }\n\n"
       "  @override\n"
       "  Widget build(BuildContext context) {\n"
       "    final colors = context.colors;\n"
       "    final settings = context.watch<SettingsController>();\n")
assert old in s
s=s.replace(old,new,1)
old2 = ("      tabBuilder: (context, localIndex) {\n"
        "        final global = visibleIndices[localIndex.clamp(0, visibleIndices.length - 1)];\n"
        "        return CupertinoTabView(builder: (context) => _tabDefs[global].screen);\n"
        "      },\n")
new2 = ("      tabBuilder: (context, localIndex) {\n"
        "        final global = visibleIndices[localIndex.clamp(0, visibleIndices.length - 1)];\n"
        "        final showWarning = kIsWeb && BrowserTabCoordinator.instance.hasOtherActiveTabs;\n"
        "        return Column(\n"
        "          children: [\n"
        "            if (showWarning)\n"
        "              Container(\n"
        "                width: double.infinity,\n"
        "                color: colors.orange,\n"
        "                child: SafeArea(\n"
        "                  bottom: false,\n"
        "                  child: Padding(\n"
        "                    padding: const EdgeInsets.all(10),\n"
        "                    child: Text('Приложение уже открыто в другой вкладке.', style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.w600)),\n"
        "                  ),\n"
        "                ),\n"
        "              ),\n"
        "            Expanded(child: CupertinoTabView(builder: (context) => _tabDefs[global].screen)),\n"
        "          ],\n"
        "        );\n"
        "      },\n")
assert old2 in s
s=s.replace(old2,new2,1)
p.write_text(s,encoding="utf-8")
print("done")
