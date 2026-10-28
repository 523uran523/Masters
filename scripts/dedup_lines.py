from pathlib import Path
p=Path(r"C:\Users\523ur\Documents\MyProjects\Apps\Masters\lib\data\app_database.dart")
lines = p.read_text(encoding="utf-8").splitlines(keepends=True)
# locate first method start
first = next((i for i,l in enumerate(lines) if l.strip().startswith("Future<List<String>> integrityIssues()")), None)
assert first is not None
# find second matching line
second = next(i for i in range(first+1, len(lines)) if lines[i].strip().startswith("Future<List<String>> integrityIssues()"))
# backtrack to previous method comment line
startSecond = second
while startSecond>0 and lines[startSecond-1].strip() != "":
    startSecond -=1
# ensure there is a doc comment line
if startSecond>0 and lines[startSecond-1].strip().startswith("///"):
    startSecond -=1
# find next close() after second
endSecond = None
for i in range(second, len(lines)):
    if lines[i].strip() == "Future<void> close() => database.close();":
        endSecond = i
        break
assert endSecond is not None
print("removing lines", startSecond+1, "to", endSecond)
out = lines[:startSecond] + [lines[endSecond]] + lines[endSecond+1:]
p.write_text("".join(out), encoding="utf-8")
print("done")
