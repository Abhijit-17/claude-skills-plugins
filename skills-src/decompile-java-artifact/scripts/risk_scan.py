#!/usr/bin/env python3
"""risk_scan.py <out-dir> [--osv-only]

Writes RISKS.md and _meta/risks.json. Four parts:
  A. Secrets in config and code. VALUES ARE MASKED in the report.
  B. Config hardening (actuator, H2 console, debug, stack traces, CORS, CSRF ...).
  C. Code risks (SQL built with +, deserialization, command execution, weak hash, trust-all TLS ...).
  D. Libraries: known bad versions (built-in list) and OSV CVE query when the network allows.
Pattern based: it finds candidates. A human or Claude must confirm each one.
"""
import json, os, re, sys, urllib.request

out = sys.argv[1]
OSV_ONLY = '--osv-only' in sys.argv
NO_OSV = os.environ.get('DJA_NO_OSV') == '1'
findings = []


def add(sev, part, title, where, detail=''):
    findings.append(dict(sev=sev, part=part, title=title, where=where, detail=detail))


def mask(v):
    v = v.strip().strip('"\'')
    if v == '': return '(empty)'
    m = re.fullmatch(r'\$\{[^}:]*(?::(.*))?\}', v)
    if m:                                                      # placeholder
        if m.group(1) is None: return None                     # no default: not a secret
        d = m.group(1)
        return 'placeholder default ' + ('(empty)' if d == '' else (d[:2] + '… (len %d)' % len(d) if len(d) > 4 else '*' * len(d)))
    if len(v) <= 4: return '*' * len(v) + ' (len %d)' % len(v)
    return '%s… (len %d)' % (v[:2], len(v))


def walk(base, exts):
    root = os.path.join(out, base)
    for dp, _, fs in os.walk(root):
        for fn in fs:
            if fn.lower().endswith(exts):
                p = os.path.join(dp, fn)
                try: yield os.path.relpath(p, out), open(p, encoding='utf-8', errors='replace').read().splitlines()
                except Exception: pass


SECRET_KEY = r'(?:password|passwd|pwd|secret|token|api[-_.]?key|apikey|private[-_.]?key|credential|access[-_.]?key|client[-_.]?secret|auth[-_.]?token|authorization)'
TOKEN_PATTERNS = [
    (r'AKIA[0-9A-Z]{16}', 'AWS access key ID'),
    (r'-----BEGIN (?:RSA |EC |DSA |OPENSSH |ENCRYPTED )?PRIVATE KEY-----', 'Private key block'),
    (r'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}', 'JWT'),
    (r'xox[abprs]-[A-Za-z0-9-]{10,}', 'Slack token'),
    (r'gh[pousr]_[A-Za-z0-9]{30,}', 'GitHub token'),
    (r'AccountKey=[A-Za-z0-9+/=]{20,}', 'Azure storage account key'),
    (r'SharedAccessKey=[A-Za-z0-9+/=]{20,}', 'Azure shared access key'),
    (r'sk-[A-Za-z0-9]{20,}', 'API secret key (sk-)'),
]
CFG_EXT = ('.properties', '.yml', '.yaml', '.xml', '.json', '.conf', '.env', '.ini', '.txt', '.sql')

if not OSV_ONLY:
    # ---- A. Secrets ----------------------------------------------------------
    for base in ('src/main/resources', 'src/main/webapp'):
        for rel, lines in walk(base, CFG_EXT):
            if os.path.basename(rel) in ('git.properties', 'build-info.properties'): continue
            for n, l in enumerate(lines, 1):
                if l.lstrip().startswith(('#', '<!--', '//')): continue
                m = re.match(r'\s*([\w.\-\[\]]*%s[\w.\-\[\]]*)\s*[=:]\s*(.*)$' % SECRET_KEY, l, re.I)
                if m and not rel.endswith(('.xml', '.sql', '.json')):
                    mv = mask(m.group(2))
                    if mv: add('MEDIUM' if mv == '(empty)' or mv.startswith('placeholder') else 'HIGH', 'A', 'Secret-like value in config', '%s:%d' % (rel, n), '%s = %s' % (m.group(1), mv))
                for m in re.finditer(r'(?:p:|name=")(\w*%s\w*)"?\s*(?:=|value=)\s*"([^"]*)"' % SECRET_KEY, l, re.I):
                    mv = mask(m.group(2))
                    if mv: add('MEDIUM' if mv == '(empty)' or mv.startswith('placeholder') else 'HIGH', 'A', 'Secret-like value in XML', '%s:%d' % (rel, n), '%s = %s' % (m.group(1), mv))
                for m in re.finditer(r'(jdbc:[^\s"\'<>}]+)', l):
                    url = m.group(1)
                    if re.search(r'(?i)password=|//[^/@:]+:[^@/]+@|^jdbc:oracle:[a-z]+:[^/@:]+/[^@]+@', url):
                        safe = re.sub(r'(?i)(password=)[^&;]*', r'\1***', url)
                        safe = re.sub(r'//([^:/@]+):[^@/]+@', r'//\1:***@', safe)
                        safe = re.sub(r'^(jdbc:oracle:[a-z]+:[^/@:]+)/[^@]+@', r'\1/***@', safe)
                        add('HIGH', 'A', 'Credentials inside a JDBC URL', '%s:%d' % (rel, n), safe)
                    else:
                        add('INFO', 'A', 'Database URL', '%s:%d' % (rel, n), url)
                for pat, name in TOKEN_PATTERNS:
                    if re.search(pat, l): add('HIGH', 'A', name, '%s:%d' % (rel, n), '(value hidden)')
    for rel, lines in walk('src/main/java', ('.java',)):
        for n, l in enumerate(lines, 1):
            m = re.search(r'\b(\w*%s\w*)\s*=\s*"([^"]+)"' % SECRET_KEY, l, re.I)
            if m and not re.search(r'(?i)(message|label|param|header|field|column|name|key|path|url|endpoint|property|prop|attr|template|view|form|error|regex|pattern)$', m.group(1)):
                add('HIGH', 'A', 'Hard-coded secret-like string in code', '%s:%d' % (rel, n), '%s = %s' % (m.group(1), mask(m.group(2))))
            for pat, name in TOKEN_PATTERNS:
                if re.search(pat, l): add('HIGH', 'A', name + ' in code', '%s:%d' % (rel, n), '(value hidden)')

    # ---- B. Config hardening -------------------------------------------------
    CFG_RULES = [
        (r'management\.endpoints\.web\.exposure\.include\s*[=:]\s*["\']?(\*|.*\b(env|heapdump|threaddump|shutdown|configprops|beans|loggers|mappings)\b)', 'HIGH', 'Actuator exposes sensitive endpoints'),
        (r'management\.endpoint\.shutdown\.(enabled|access)\s*[=:]\s*(true|unrestricted)', 'HIGH', 'Actuator shutdown endpoint enabled'),
        (r'management\.endpoint\.\w+\.show-values\s*[=:]\s*always', 'HIGH', 'Actuator shows raw config values'),
        (r'spring\.h2\.console\.enabled\s*[=:]\s*true', 'HIGH', 'H2 web console enabled'),
        (r'server\.error\.include-(stacktrace|exception|message)\s*[=:]\s*(always|true)', 'MEDIUM', 'Error responses include internal details'),
        (r'^\s*debug\s*[=:]\s*true', 'MEDIUM', 'Spring debug mode on'),
        (r'logging\.level\.(root|org\.springframework\.security)\s*[=:]\s*(DEBUG|TRACE)', 'MEDIUM', 'DEBUG/TRACE logging for root or security'),
        (r'(spring\.jpa\.show-sql|jpa\.showSql|hibernate\.show_sql)\s*[=:]\s*true', 'LOW', 'SQL statements are logged'),
        (r'spring\.jpa\.hibernate\.ddl-auto\s*[=:]\s*(create|create-drop|update)', 'MEDIUM', 'Hibernate changes the schema at start'),
        (r'(server\.ssl\.enabled\s*[=:]\s*false)', 'LOW', 'TLS disabled in the app'),
        (r'spring\.devtools\.remote\.secret', 'HIGH', 'Spring DevTools remote enabled'),
        (r'allowed-?origins\s*[=:]\s*["\']?\*', 'MEDIUM', 'CORS allows all origins (config)'),
    ]
    for base in ('src/main/resources', 'src/main/webapp'):
        for rel, lines in walk(base, ('.properties', '.yml', '.yaml')):
            # flatten simple YAML nesting to dotted keys
            stack = []
            for n, l in enumerate(lines, 1):
                s = l
                if rel.endswith(('.yml', '.yaml')):
                    m = re.match(r'^(\s*)([\w.\-]+):\s*(.*)$', l)
                    if m:
                        ind = len(m.group(1)); stack = [(i, k) for i, k in stack if i < ind] + [(ind, m.group(2))]
                        s = '.'.join(k for _, k in stack) + '=' + m.group(3)
                for pat, sev, title in CFG_RULES:
                    if re.search(pat, s, re.I): add(sev, 'B', title, '%s:%d' % (rel, n), s.strip()[:160])
    for rel, lines in walk('src/main/webapp', ('.xml',)):
        t = '\n'.join(lines)
        if os.path.basename(rel) == 'web.xml' and '<security-constraint' not in t:
            add('INFO', 'B', 'web.xml has no security-constraint (security may be in code or the server)', rel)

    # ---- C. Code risks -------------------------------------------------------
    CODE_RULES = [
        (r'\b(createQuery|createNativeQuery|prepareStatement|prepareCall|executeQuery|executeUpdate|addBatch|execute|queryForObject|queryForList|queryForMap|query|update|batchUpdate|sql)\(\s*"[^"]*"\s*\+\s*(?!")', 'HIGH', 'SQL or JPQL built with string concatenation (injection risk)'),
        (r'\b(createQuery|createNativeQuery|prepareStatement|executeQuery|execute)\(\s*(String\.format|\w+\s*\+)', 'HIGH', 'Query built from a variable (check for injection)'),
        (r'new\s+ObjectInputStream\(|\.readObject\(\)', 'HIGH', 'Java deserialization'),
        (r'XMLDecoder|XStream\b|enableDefaultTyping|activateDefaultTyping|@JsonTypeInfo\(use\s*=\s*JsonTypeInfo\.Id\.CLASS', 'HIGH', 'Unsafe polymorphic deserialization'),
        (r'Runtime\.getRuntime\(\)\.exec\(|new\s+ProcessBuilder\(', 'HIGH', 'Operating-system command execution'),
        (r'\bimplements\s+X509TrustManager\b|NoopHostnameVerifier|ALLOW_ALL_HOSTNAME_VERIFIER|setHostnameVerifier\(\s*\(\w*,\s*\w*\)\s*->\s*true', 'HIGH', 'TLS certificate or host-name check turned off'),
        (r'MessageDigest\.getInstance\("(MD5|SHA-?1)"\)|DigestUtils\.(md5|sha1)', 'MEDIUM', 'Weak hash (MD5/SHA-1)'),
        (r'Cipher\.getInstance\("(DES|DESede|RC4|AES/ECB|AES")', 'MEDIUM', 'Weak cipher or ECB mode'),
        (r'NoOpPasswordEncoder|\{noop\}', 'HIGH', 'Passwords stored without hashing'),
        (r'csrf\(\)\.disable\(\)|csrf\(\s*\w+\s*->\s*\w+\.disable\(\)\)|csrf\(AbstractHttpConfigurer::disable\)', 'MEDIUM', 'CSRF protection disabled'),
        (r'(antMatchers|requestMatchers|mvcMatchers)\(\s*"/\*\*"\s*\)\.permitAll\(\)|anyRequest\(\)\.permitAll\(\)', 'HIGH', 'All requests permitted'),
        (r'allowedOrigins\(\s*"\*"|allowedOriginPatterns\(\s*"\*"|addAllowedOrigin\("\*"\)', 'MEDIUM', 'CORS allows all origins (code)'),
        (r'@CrossOrigin\s*$|@CrossOrigin\(\s*\)', 'LOW', '@CrossOrigin without origins (default: all)'),
        (r'DocumentBuilderFactory\.newInstance\(\)|SAXParserFactory\.newInstance\(\)|XMLInputFactory\.newInstance\(\)', 'LOW', 'XML parser: check XXE protection features'),
        (r'new\s+Random\(\)', 'LOW', 'java.util.Random (not for tokens or passwords)'),
        (r'printStackTrace\(\)', 'LOW', 'printStackTrace (logs to stdout)'),
        (r'"http://(?!localhost|127\.0\.0\.1|www\.w3\.org|java\.sun\.com|xmlns\.jcp\.org|www\.springframework\.org|maven\.apache\.org|schemas\.|json-schema\.org)[^"]+"', 'LOW', 'Plain HTTP URL in code'),
    ]
    for rel, lines in walk('src/main/java', ('.java',)):
        for n, l in enumerate(lines, 1):
            for pat, sev, title in CODE_RULES:
                if re.search(pat, l): add(sev, 'C', title, '%s:%d' % (rel, n), l.strip()[:180])

# ---- D. Libraries -------------------------------------------------------------
deps_file = os.path.join(out, '_meta', 'dependencies.json')
deps = json.load(open(deps_file)) if os.path.exists(deps_file) else []


def vt(v):
    return tuple(int(x) for x in re.findall(r'\d+', v)[:4]) or (0,)


KNOWN = [  # (artifact regex, bad-if-version-below, severity, note)
    (r'^log4j-core$', '2.17.1', 'HIGH', 'Log4Shell family (CVE-2021-44228, -45046, -44832)'),
    (r'^log4j$', '99', 'HIGH', 'Log4j 1.x is end of life (CVE-2019-17571, CVE-2022-23305)'),
    (r'^spring-(core|beans|webmvc|web)$', '5.3.18', 'HIGH', 'Spring4Shell (CVE-2022-22965) and older issues'),
    (r'^spring-(core|beans|webmvc|web|context)$', '6.0.0', 'MEDIUM', 'Spring Framework 5.x: open-source support ended'),
    (r'^spring-boot$', '3.0.0', 'MEDIUM', 'Spring Boot 2.x: open-source support ended'),
    (r'^commons-text$', '1.10.0', 'HIGH', 'Text4Shell (CVE-2022-42889)'),
    (r'^snakeyaml$', '2.0', 'HIGH', 'CVE-2022-1471 (unsafe constructor)'),
    (r'^commons-collections$', '3.2.2', 'HIGH', 'Deserialization gadget (CVE-2015-7501)'),
    (r'^jackson-databind$', '2.13.4', 'MEDIUM', 'Many CVEs before 2.13.4.2'),
    (r'^xstream$', '1.4.20', 'HIGH', 'Many RCE CVEs'),
    (r'^struts2-core$', '6.1.2', 'HIGH', 'Struts 2 RCE history (S2-066 and older)'),
    (r'^h2$', '2.1.210', 'HIGH', 'CVE-2021-42392 / CVE-2022-23221 (console RCE)'),
    (r'^tomcat-embed-core$', '9.0.99', 'MEDIUM', 'Check Tomcat advisories for this version'),
    (r'^mysql-connector-java$', '99', 'LOW', 'Old artifact name; replaced by mysql-connector-j'),
]
for d in deps:
    for pat, below, sev, note in KNOWN:
        if re.match(pat, d['artifact']) and d['version'] != '?' and vt(d['version']) < vt(below):
            add(sev, 'D', 'Known risky library version', d['file'], '%s:%s %s: %s' % (d['group'], d['artifact'], d['version'], note))
            break

osv_status = 'not run'
q = [d for d in deps if d['group'] != '?' and d['version'] != '?']
json.dump({'queries': [{'package': {'ecosystem': 'Maven', 'name': '%s:%s' % (d['group'], d['artifact'])}, 'version': d['version']} for d in q]},
          open(os.path.join(out, '_meta', 'osv-query.json'), 'w'), indent=1)
if NO_OSV:
    osv_status = 'off (DJA_NO_OSV=1)'
elif q:
    try:
        req = urllib.request.Request('https://api.osv.dev/v1/querybatch', data=open(os.path.join(out, '_meta', 'osv-query.json'), 'rb').read(),
                                     headers={'Content-Type': 'application/json'})
        res = json.load(urllib.request.urlopen(req, timeout=20)).get('results', [])
        hit = 0
        for d, r in zip(q, res):
            ids = [v['id'] for v in r.get('vulns', [])]
            if ids:
                hit += 1
                add('HIGH' if len(ids) >= 3 else 'MEDIUM', 'D', 'OSV: known vulnerabilities', d['file'],
                    '%s:%s %s: %d (%s%s)' % (d['group'], d['artifact'], d['version'], len(ids), ', '.join(ids[:6]), ', …' if len(ids) > 6 else ''))
        osv_status = 'done: %d of %d libraries have OSV entries (%d libraries without group were not checked)' % (hit, len(q), len(deps) - len(q))
    except Exception as e:
        osv_status = 'FAILED (no network?): %s. Run later where internet works: python3 risk_scan.py <out> --osv-only' % type(e).__name__

# ---- Write -----------------------------------------------------------------
rp = os.path.join(out, '_meta', 'risks.json')
if OSV_ONLY and os.path.exists(rp):
    old = [f for f in json.load(open(rp))['findings'] if f['part'] != 'D']
    findings = old + findings
json.dump(dict(osv=osv_status, findings=findings), open(rp, 'w'), indent=1)
order = {'HIGH': 0, 'MEDIUM': 1, 'LOW': 2, 'INFO': 3}
names = {'A': 'A. Secrets (values masked)', 'B': 'B. Config hardening', 'C': 'C. Code risks', 'D': 'D. Libraries'}
W = ['# Risk scan', '', 'Pattern based: each line is a CANDIDATE. Confirm it in the code before you act. Secret values are masked.', '',
     '| Severity | Count |', '|---|---|']
cnt = {}
for f in findings: cnt[f['sev']] = cnt.get(f['sev'], 0) + 1
W += ['| %s | %d |' % (s, cnt.get(s, 0)) for s in ('HIGH', 'MEDIUM', 'LOW', 'INFO')]
W += ['', 'OSV CVE check: ' + osv_status, '']
for p in 'ABCD':
    fs = sorted([f for f in findings if f['part'] == p], key=lambda f: (order[f['sev']], f['title'], f['where']))
    W += ['## %s (%d)' % (names[p], len(fs)), '']
    if not fs: W += ['(none found)', '']; continue
    W += ['| Sev | Finding | Where | Detail |', '|---|---|---|---|']
    W += ['| %s | %s | `%s` | %s |' % (f['sev'], f['title'], f['where'], f['detail'].replace('|', '\\|')) for f in fs]
    W.append('')
open(os.path.join(out, 'RISKS.md'), 'w').write('\n'.join(W))
print('Risks:    %s (RISKS.md). OSV: %s' % (', '.join('%s %d' % (s, cnt.get(s, 0)) for s in ('HIGH', 'MEDIUM', 'LOW', 'INFO')), osv_status))
