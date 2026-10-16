#!/usr/bin/env python3
"""deps.py <lib-dir|''> <out-dir> <unpacked-dir>

Makes DEPENDENCIES.md, pom-reconstructed.xml and _meta/dependencies.json.
Data sources, best first: CycloneDX SBOM (Spring Boot 3.3+), the library's own
META-INF/maven/**/pom.properties, then the file name (group unknown).
"""
import glob, json, os, re, sys, zipfile

lib, out, u = sys.argv[1], sys.argv[2], sys.argv[3]

sbom = {}
for s in glob.glob(os.path.join(u, 'META-INF', 'sbom', '*.json')):
    try:
        for c in json.load(open(s)).get('components', []):
            if c.get('name') and c.get('version'):
                sbom['%s-%s.jar' % (c['name'], c['version'])] = (c.get('group') or '?', c['name'], c['version'])
    except Exception:
        pass

rows = []
if lib and os.path.isdir(lib):
    for j in sorted(glob.glob(os.path.join(lib, '*.jar'))):
        fn = os.path.basename(j)
        if fn in sbom:
            rows.append(sbom[fn] + (fn, 'SBOM')); continue
        g = a = v = None; src = 'pom.properties'
        try:
            with zipfile.ZipFile(j) as z:
                props = [n for n in z.namelist() if n.startswith('META-INF/maven/') and n.endswith('pom.properties')]
                base = fn[:-4]; pick = None
                for p in props:
                    d = dict(l.split('=', 1) for l in z.read(p).decode('utf-8', 'replace').splitlines()
                             if '=' in l and not l.startswith('#'))
                    if pick is None or base.startswith(d.get('artifactId', '?')): pick = d
                if pick:
                    g, a, v = pick.get('groupId'), pick.get('artifactId'), pick.get('version')
                else:
                    mf = z.read('META-INF/MANIFEST.MF').decode('utf-8', 'replace') if 'META-INF/MANIFEST.MF' in z.namelist() else ''
                    m = re.search(r'^Bundle-SymbolicName:\s*([^;\r\n]+)', mf, re.M)
                    src = 'GUESS: no pom.properties; OSGi name %s' % (m.group(1).strip() if m else '-')
        except Exception as e:
            src = 'unreadable: %s' % e
        if not a:
            m = re.match(r'(.+?)-(\d[\w.\-]*)$', fn[:-4])
            a, v = (m.group(1), m.group(2)) if m else (fn[:-4], v or '?')
            g = g or '?'
        rows.append((g or '?', a, v or '?', fn, src))

os.makedirs(os.path.join(out, '_meta'), exist_ok=True)
json.dump([dict(group=g, artifact=a, version=v, file=f, source=s) for g, a, v, f, s in rows],
          open(os.path.join(out, '_meta', 'dependencies.json'), 'w'), indent=1)
exact = sum(1 for r in rows if not r[4].startswith(('GUESS', 'unreadable')) and r[0] != '?')
with open(os.path.join(out, 'DEPENDENCIES.md'), 'w') as f:
    f.write('# Libraries in the artifact (%d, %d with exact coordinates)\n\n' % (len(rows), exact))
    f.write('This is the RESOLVED list (direct + transitive). The embedded pom.xml, if present, has the DECLARED list.\n')
    f.write('Libraries that the server supplies (scope `provided`, for example the Servlet API) are NOT here.\n\n')
    f.write('| groupId | artifactId | version | file | data from |\n|---|---|---|---|---|\n')
    for r in rows: f.write('| %s | %s | %s | %s | %s |\n' % r)
with open(os.path.join(out, 'pom-reconstructed.xml'), 'w') as f:
    f.write('<?xml version="1.0" encoding="UTF-8"?>\n<!-- Made from the lib/ folder of the deployed artifact.\n'
            '     All libraries are listed, also transitive ones. Container-provided libraries are NOT in lib/. -->\n'
            '<project xmlns="http://maven.apache.org/POM/4.0.0">\n  <modelVersion>4.0.0</modelVersion>\n'
            '  <groupId>reconstructed</groupId>\n  <artifactId>reconstructed</artifactId>\n  <version>0</version>\n  <dependencies>\n')
    for g, a, v, fn, src in rows:
        f.write('    <dependency><groupId>%s</groupId><artifactId>%s</artifactId><version>%s</version></dependency><!-- %s -->\n' % (g, a, v, src))
    f.write('  </dependencies>\n</project>\n')
print('Libs:     %d library JARs, %d with exact coordinates (DEPENDENCIES.md)' % (len(rows), exact))
