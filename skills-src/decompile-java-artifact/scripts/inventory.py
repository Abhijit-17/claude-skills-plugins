#!/usr/bin/env python3
"""inventory.py <out-dir>

Reads <out>/src/main/java (CFR output) and the Spring XML / web.xml files.
Writes INVENTORY.md and _meta/inventory.json:
  - classes by role (stereotype annotation, interface, base class)
  - HTTP endpoints (method, URL, handler)
  - constructor / field wiring (who uses whom), with fan-in
  - entities and tables, messaging listeners, schedulers, outbound HTTP clients
  - configuration keys used in code (@Value, @ConfigurationProperties)
  - beans declared in Spring XML, servlets and filters in web.xml
Regex based. It is a map for a human or for Claude, not a compiler.
"""
import collections, json, os, re, sys

out = sys.argv[1]
src = os.path.join(out, 'src', 'main', 'java')

ROLE_ANN = [
    ('RestController', 'web'), ('Controller', 'web'), ('ControllerAdvice', 'web'), ('RestControllerAdvice', 'web'),
    ('Service', 'service'), ('Repository', 'repository'), ('Entity', 'entity'), ('MappedSuperclass', 'entity'),
    ('Embeddable', 'entity'), ('Document', 'entity'), ('Configuration', 'config'), ('SpringBootApplication', 'bootstrap'),
    ('ConfigurationProperties', 'config'), ('Aspect', 'cross-cutting'), ('Component', 'component'),
    ('FeignClient', 'outbound-client'), ('WebServlet', 'web'), ('WebFilter', 'web'), ('WebListener', 'web'),
]
ROLE_BASE = [
    (r'\b(JpaRepository|CrudRepository|PagingAndSortingRepository|Repository|MongoRepository|ReactiveCrudRepository)<', 'repository'),
    (r'\b(WebMvcConfigurer|WebSecurityConfigurerAdapter|AbstractDispatcherServletInitializer|AbstractAnnotationConfigDispatcherServletInitializer|WebApplicationInitializer|SpringBootServletInitializer)\b', 'config'),
    (r'\b(HttpServlet|Filter|OncePerRequestFilter|HandlerInterceptor)\b', 'web'),
    (r'\b(RowMapper|ResultSetExtractor)<', 'repository'),
    (r'\b(Validator|Formatter|Converter)<?', 'web-helper'),
]
MAP_ANN = {'GetMapping': 'GET', 'PostMapping': 'POST', 'PutMapping': 'PUT', 'DeleteMapping': 'DELETE',
           'PatchMapping': 'PATCH', 'RequestMapping': '*'}

DECL = re.compile(r'^(\s*)(?:(?:public|protected|private|abstract|final|static|sealed|non-sealed|strictfp)\s+)*'
                  r'(class|interface|enum|record|@interface)\s+(\w+)(.*)$')
METHOD = re.compile(r'^\s+(?:(?:public|protected|private|abstract|final|static|synchronized|default|native)\s+)*'
                    r'(?:<[^>]+>\s+)?([\w.<>\[\], ?]+)\s+(\w+)\s*\(([^)]*)\)')
STR = re.compile(r'"((?:[^"\\]|\\.)*)"')


def ann_name(a):
    return re.match(r'@([\w.]+)', a).group(1).split('.')[-1]


def _strings_from(s):
    """String literals at the start of s: one "x", or a {"a","b"} array. Braces inside strings are kept."""
    s = s.lstrip()
    if s.startswith('"'):
        m = STR.match(s); return [m.group(1)] if m else []
    if not s.startswith('{'): return []
    res, i, buf, ins = [], 1, '', False
    while i < len(s):
        ch = s[i]
        if ins:
            if ch == '\\': buf += s[i:i + 2]; i += 2; continue
            if ch == '"': res.append(buf); buf = ''; ins = False
            else: buf += ch
        elif ch == '"': ins = True
        elif ch == '}': break
        i += 1
    return res


def ann_paths(a):
    m = re.search(r'\b(?:value|path)\s*=\s*', a)
    if m: return _strings_from(a[m.end():]) or ['']
    m = re.match(r'@[\w.]+\(\s*', a)
    if m and a[m.end():].lstrip()[:1] in ('"', '{'): return _strings_from(a[m.end():]) or ['']
    return ['']


def ann_methods(a):
    m = re.search(r'method\s*=\s*\{?([^})]*)', a)
    return re.findall(r'RequestMethod\.(\w+)', m.group(1)) if m else []


def join(p, q):
    s = ('/' + p.strip('/') + '/' + q.lstrip('/')).replace('//', '/')
    return s if s == '/' else s.rstrip('/') or '/'


classes, endpoints, listeners, schedulers, outbound, config_keys, entities = [], [], [], [], [], [], []
by_simple = {}

for dp, _, fs in os.walk(src):
    for fn in sorted(fs):
        if not fn.endswith('.java') or fn == 'package-info.java': continue
        path = os.path.join(dp, fn); rel = os.path.relpath(path, out)
        try: lines = open(path, encoding='utf-8', errors='replace').read().splitlines()
        except Exception: continue
        pkg = next((l[8:].strip(' ;') for l in lines if l.startswith('package ')), '')
        pending, cls, cls_anns, prefixes, cur = [], None, [], [''], None
        deps, fields = [], []
        for i, line in enumerate(lines):
            s = line.strip()
            if s.startswith('@'):
                # join multi-line annotations
                a = s; k = i
                while a.count('(') > a.count(')') and k + 1 < len(lines):
                    k += 1; a += ' ' + lines[k].strip()
                pending.append(a); continue
            d = DECL.match(line)
            if d and cls is None and len(d.group(1)) == 0:
                kind, name, rest = d.group(2), d.group(3), d.group(4)
                cls = name; cls_anns = pending; pending = []
                names = [ann_name(a) for a in cls_anns]
                roles = sorted({r for n, r in ROLE_ANN if n in names} | {r for p, r in ROLE_BASE if re.search(p, rest)})
                if not roles: roles = ['interface'] if kind == 'interface' else ['other']
                prefixes = [p for a in cls_anns if ann_name(a) == 'RequestMapping' for p in ann_paths(a)] or ['']
                table = next((STR.findall(a)[0] for a in cls_anns if ann_name(a) == 'Table' and STR.findall(a)), None)
                if 'Entity' in names: entities.append(dict(cls='%s.%s' % (pkg, name), table=table or name))
                for a in cls_anns:
                    if ann_name(a) == 'FeignClient': outbound.append(dict(where=name, kind='Feign', target=' '.join(STR.findall(a))))
                    if ann_name(a) == 'ConfigurationProperties': config_keys.append(dict(key=(STR.findall(a) or ['?'])[0] + '.*', where=name))
                cur = dict(name=name, fqcn='%s.%s' % (pkg, name) if pkg else name, kind=kind, file=rel,
                           roles=roles, annotations=sorted(set(names)), extends=rest.strip(' {'), deps=deps, methods=0)
                classes.append(cur); by_simple[name] = cur
                continue
            if cls is None:
                pending = []; continue
            # members (indent 4 = top-level members of the main class)
            ind = len(line) - len(line.lstrip(' '))
            mm = METHOD.match(line) if ind == 4 else None
            if ind == 4 and re.match(r'\s+(?:public |protected |private )?%s\s*\(' % re.escape(cls), line):
                params = re.search(r'\(([^)]*)\)', line)
                if params:
                    for p in params.group(1).split(','):
                        t = p.strip().split(' ')[-2] if len(p.strip().split(' ')) >= 2 else ''
                        if t and t[0].isupper(): deps.append(re.sub(r'<.*', '', t))
            elif mm:
                cur['methods'] += 1
                names = [ann_name(a) for a in pending]
                for a in pending:
                    n = ann_name(a)
                    if n in MAP_ANN:
                        verbs = ann_methods(a) or [MAP_ANN[n]]
                        for pre in prefixes:
                            for p in ann_paths(a):
                                for v in verbs:
                                    endpoints.append(dict(verb=v, url=join(pre, p), handler='%s#%s' % (cls, mm.group(2)), file=rel, line=i + 1))
                    if n in ('KafkaListener', 'JmsListener', 'RabbitListener', 'SqsListener', 'StreamListener', 'EventListener', 'TransactionalEventListener'):
                        listeners.append(dict(kind=n, target=' '.join(STR.findall(a)) or '-', handler='%s#%s' % (cls, mm.group(2))))
                    if n == 'Scheduled':
                        schedulers.append(dict(spec=a[len('@Scheduled'):], handler='%s#%s' % (cls, mm.group(2))))
            elif ind == 4 and re.match(r'\s+(?:private|protected|public)?\s*(?:final\s+)?[\w.<>, ?]+\s+\w+\s*(=|;)', line):
                if any(ann_name(a) in ('Autowired', 'Inject', 'Resource') for a in pending):
                    t = line.strip().split()
                    t = [x for x in t if x not in ('private', 'protected', 'public', 'final', 'static')]
                    if t: deps.append(re.sub(r'<.*', '', t[0]))
            for a in pending:
                if ann_name(a) == 'Value':
                    for k in re.findall(r'\$\{([^}:]+)', a): config_keys.append(dict(key=k, where=cls))
            pending = []
            for k in re.findall(r'(RestTemplate|WebClient|RestClient|HttpClient|OkHttpClient|HttpURLConnection)\b', line):
                outbound.append(dict(where=cls, kind=k, target='(see code)'))

# fan-in
fan_in = collections.Counter(d for c in classes for d in set(c['deps']) if d in by_simple)
for c in classes: c['fan_in'] = fan_in.get(c['name'], 0)

# Spring XML and web.xml
xml_beans, web_xml = [], []
for base in ('src/main/resources', 'src/main/webapp'):
    root = os.path.join(out, base)
    for dp, _, fs in os.walk(root):
        for fn in fs:
            if not fn.endswith('.xml'): continue
            p = os.path.join(dp, fn); t = open(p, encoding='utf-8', errors='replace').read()
            rel = os.path.relpath(p, out)
            if '<beans' in t:
                for m in re.finditer(r'<bean\b[^>]*?\bclass="([^"]+)"', t): xml_beans.append(dict(file=rel, cls=m.group(1)))
                for m in re.finditer(r'<beans[^>]*profile="([^"]+)"', t): xml_beans.append(dict(file=rel, cls='(profile %s)' % m.group(1)))
                for m in re.finditer(r'component-scan[^>]*base-package="([^"]+)"', t): xml_beans.append(dict(file=rel, cls='(scan %s)' % m.group(1)))
            if fn == 'web.xml':
                for m in re.finditer(r'<(servlet|filter|listener)-class>([^<]+)<', t): web_xml.append(dict(kind=m.group(1), cls=m.group(2).strip()))

inv = dict(classes=classes, endpoints=endpoints, entities=entities, listeners=listeners, schedulers=schedulers,
           outbound=outbound, config_keys=config_keys, xml_beans=xml_beans, web_xml=web_xml)
os.makedirs(os.path.join(out, '_meta'), exist_ok=True)
json.dump(inv, open(os.path.join(out, '_meta', 'inventory.json'), 'w'), indent=1)

W = []
role_count = collections.Counter(r for c in classes for r in c['roles'])
W.append('# Inventory\n\nMade by inventory.py from the decompiled code (regex based). Use it as a map, then read the code.\n')
W.append('## Classes by role\n\n| Role | Count |\n|---|---|')
W += ['| %s | %d |' % kv for kv in sorted(role_count.items(), key=lambda kv: -kv[1])]
pk = collections.Counter(c['fqcn'].rsplit('.', 1)[0] for c in classes)
W.append('\n## Packages\n\n| Package | Classes |\n|---|---|')
W += ['| `%s` | %d |' % kv for kv in sorted(pk.items())]
W.append('\n## HTTP endpoints (%d)\n\n| Verb | URL | Handler | File:line |\n|---|---|---|---|' % len(endpoints))
W += ['| %s | `%s` | `%s` | %s:%d |' % (e['verb'], e['url'], e['handler'], e['file'], e['line'])
      for e in sorted(endpoints, key=lambda e: (e['url'], e['verb']))]
W.append('\n## Wiring: most used classes (fan-in)\n\n| Class | Role | Used by (count) |\n|---|---|---|')
W += ['| `%s` | %s | %d |' % (c['name'], ','.join(c['roles']), c['fan_in'])
      for c in sorted(classes, key=lambda c: -c['fan_in'])[:25] if c['fan_in']]
W.append('\n## Dependencies of each web / service class\n')
W += ['- `%s` → %s' % (c['name'], ', '.join('`%s`' % d for d in c['deps']) or '(none)')
      for c in classes if set(c['roles']) & {'web', 'service', 'bootstrap', 'config'}]
W.append('\n## Entities (%d)\n\n| Entity | Table |\n|---|---|' % len(entities))
W += ['| `%s` | `%s` |' % (e['cls'], e['table']) for e in entities]
for title, rows, fmt in (('Messaging and event listeners', listeners, lambda r: '- %s `%s` → `%s`' % (r['kind'], r['target'], r['handler'])),
                         ('Scheduled jobs', schedulers, lambda r: '- `%s` %s' % (r['handler'], r['spec'])),
                         ('Outbound HTTP clients', outbound, lambda r: '- %s in `%s` %s' % (r['kind'], r['where'], r['target'])),
                         ('Config keys used in code', config_keys, lambda r: '- `%s` (in `%s`)' % (r['key'], r['where'])),
                         ('Beans and scans in Spring XML', xml_beans, lambda r: '- %s: `%s`' % (r['file'], r['cls'])),
                         ('web.xml servlets, filters, listeners', web_xml, lambda r: '- %s `%s`' % (r['kind'], r['cls']))):
    seen = []
    for r in rows:
        line = fmt(r)
        if line not in seen: seen.append(line)
    W.append('\n## %s (%d)\n' % (title, len(seen)))
    W += seen or ['(none found)']
open(os.path.join(out, 'INVENTORY.md'), 'w').write('\n'.join(W) + '\n')
print('Inventory: %d classes, %d endpoints, %d entities, %d listeners, %d scheduled, %d outbound uses (INVENTORY.md)'
      % (len(classes), len(endpoints), len(entities), len(listeners), len(schedulers), len(outbound)))
