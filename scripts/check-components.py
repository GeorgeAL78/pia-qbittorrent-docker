#!/usr/bin/env python3
"""Weekly component check. Opens one issue per newer version, assigned to the
repository owner, for:

  * master's Dockerfile pins: qBittorrent, libtorrent (2.0.x), Boost, Ninja
  * the beta branch's pins: qBittorrent and libtorrent including pre-releases
    (and Boost / Ninja when beta pins them differently from master)
  * the unpinned Alpine packages in the published :latest image: OpenVPN,
    WireGuard tools, iptables, Qt6 - newer when the Alpine branch has a newer
    build than the image contains, i.e. a rebuild would pick it up

Dependabot cannot see any of these. The Alpine base image itself is covered by
Dependabot's docker ecosystem.

Env: GITHUB_TOKEN, GITHUB_REPOSITORY, GITHUB_REPOSITORY_OWNER.
DRY_RUN=1 prints what would be opened instead of opening it.
SKIP_PACKAGES=1 skips the Alpine package check (it needs docker).
"""
import base64, json, os, re, subprocess, sys, urllib.request

API = 'https://api.github.com'
TOKEN = os.environ.get('GITHUB_TOKEN', '')
REPO = os.environ.get('GITHUB_REPOSITORY', 'GeorgeAL78/pia-qbittorrent-docker')
OWNER = os.environ.get('GITHUB_REPOSITORY_OWNER', REPO.split('/')[0])
DRY = os.environ.get('DRY_RUN') == '1'
DOCKERFILE = sys.argv[1] if len(sys.argv) > 1 else 'Dockerfile'
BETA_DOCKERFILE = sys.argv[2] if len(sys.argv) > 2 else None   # local file for testing
IMAGE = os.environ.get('IMAGE', 'gjergjk/pia-qbittorrent:latest')


def api(path, method='GET', body=None):
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None)
    req.add_header('Accept', 'application/vnd.github+json')
    if TOKEN:
        req.add_header('Authorization', 'Bearer ' + TOKEN)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


_release_cache = {}
def releases(repo):
    if repo not in _release_cache:
        out, page = [], 1
        while page <= 5:
            batch = api(f'/repos/{repo}/releases?per_page=100&page={page}')
            out += [r for r in batch if not r['draft']]
            if len(batch) < 100:
                break
            page += 1
        _release_cache[repo] = out
    return _release_cache[repo]


STAGE = {'beta': 0, 'rc': 1, None: 2}
def key(v):
    """'5.3.0rc1' < '5.3.0' ; '1.91.0-1' > '1.91.0'."""
    m = re.fullmatch(r'(\d+)\.(\d+)\.(\d+)(?:(beta|rc)(\d+))?(?:-(\d+))?', v)
    if not m:
        return None
    return (int(m[1]), int(m[2]), int(m[3]), STAGE[m[4]], int(m[5] or 0), int(m[6] or 0))


def latest(repo, tag_re, prerelease):
    best = None
    for r in releases(repo):
        if r['prerelease'] and not prerelease:
            continue
        m = re.fullmatch(tag_re, r['tag_name'])
        if m and key(m[1]) and (best is None or key(m[1]) > key(best[0])):
            best = (m[1], r['html_url'])
    return best


# name, pin regex, upstream repo, release-tag regex
MASTER = [
    ('qBittorrent', r'qBittorrent/tarball/release-(\d+\.\d+\.\d+)\b',
     'qbittorrent/qBittorrent', r'release-(\d+\.\d+\.\d+)'),
    ('libtorrent', r'libtorrent/releases/download/v(2\.0\.\d+)/',          # stays on 2.0.x
     'arvidn/libtorrent', r'v(2\.0\.\d+)'),
    ('Boost', r'boost/releases/download/boost-(\d+\.\d+\.\d+(?:-\d+)?)/',
     'boostorg/boost', r'boost-(\d+\.\d+\.\d+(?:-\d+)?)'),
    ('Ninja', r'ninja/archive/refs/tags/v(\d+\.\d+\.\d+)\.tar',
     'ninja-build/ninja', r'v(\d+\.\d+\.\d+)'),
]
BETA = [
    ('qBittorrent', r'qBittorrent/tarball/release-(\d+\.\d+\.\d+(?:(?:beta|rc)\d+)?)\b',
     'qbittorrent/qBittorrent', r'release-(\d+\.\d+\.\d+(?:(?:beta|rc)\d+)?)'),
    ('libtorrent', r'libtorrent/releases/download/v(\d+\.\d+\.\d+)/',     # any series
     'arvidn/libtorrent', r'v(\d+\.\d+\.\d+)'),
    MASTER[2], MASTER[3],
]
PACKAGES = [('openvpn', 'OpenVPN'), ('wireguard-tools', 'WireGuard tools'),
            ('iptables', 'iptables'), ('qt6-qtbase', 'Qt6')]


def one_pin(text, pin_re, name, where, errors):
    pins = set(re.findall(pin_re, text))
    if len(pins) != 1:
        errors.append(f'{name}: expected exactly one pin in {where}, found {sorted(pins) or "none"}')
        return None
    return pins.pop()


def check_pins(text, components, where, suffix, prerelease, skip, findings, errors):
    for name, pin_re, repo, tag_re in components:
        pinned = one_pin(text, pin_re, name, where, errors)
        if pinned is None or (name, pinned) in skip:
            continue
        found = latest(repo, tag_re, prerelease)
        if not found:
            errors.append(f'{name}: no matching release found in {repo}')
            continue
        newest, url = found
        if key(newest) <= key(pinned):
            print(f'{name}{suffix}: {pinned} is current')
            continue
        findings.append((f'{name} {newest} is available{suffix}',
                         f'The {where} pins {name} **{pinned}**; the latest release is **{newest}**.\n\n{url}'))


def check_packages(findings, errors):
    names = [p for p, _ in PACKAGES]
    cmd = ['docker', 'run', '--rm', '--user', '0', '--entrypoint', 'sh', IMAGE, '-c',
           'apk update -q >/dev/null && apk version -v ' + ' '.join(names)]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=600, check=True).stdout
    except Exception as e:
        errors.append(f'Alpine package check failed: {e}')
        return
    seen = set()
    for line in out.splitlines():
        m = re.match(r'(\S+?)-(\d\S*-r\d+)\s+([<=>])\s+(\S+)', line.strip())
        if not m:
            continue
        pkg, have, op, avail = m.groups()
        if pkg not in names:
            continue
        seen.add(pkg)
        label = dict(PACKAGES)[pkg]
        if op != '<':
            print(f'{label}: {have} is current')
            continue
        findings.append((f'{label} {avail} is available',
                         f'The published image ({IMAGE}) has {label} **{have}**; Alpine now ships '
                         f'**{avail}**. It is an unpinned Alpine package, so rebuilding the image picks it up.'))
    for pkg in set(names) - seen:
        errors.append(f'{dict(PACKAGES)[pkg]} ({pkg}) not found in {IMAGE}')


def main():
    findings, errors = [], []
    master_text = open(DOCKERFILE, encoding='utf-8').read()
    check_pins(master_text, MASTER, 'Dockerfile', '', False, set(), findings, errors)

    if BETA_DOCKERFILE:
        beta_text = open(BETA_DOCKERFILE, encoding='utf-8').read()
    else:
        beta_text = base64.b64decode(api(f'/repos/{REPO}/contents/Dockerfile?ref=beta')['content']).decode()
    # Boost / Ninja on beta only matter if beta pins them differently from master.
    same = set()
    for name, pin_re, _, _ in MASTER[2:]:
        m = re.findall(pin_re, master_text)
        if m:
            same.add((name, m[0]))
    check_pins(beta_text, BETA, 'beta branch Dockerfile', ' (beta)', True, same, findings, errors)

    if os.environ.get('SKIP_PACKAGES') != '1':
        check_packages(findings, errors)

    existing, page = set(), 1
    while page <= 10:
        batch = api(f'/repos/{REPO}/issues?state=all&labels=dependencies&per_page=100&page={page}')
        existing |= {i['title'] for i in batch}
        if len(batch) < 100:
            break
        page += 1

    for title, body in findings:
        if title in existing:
            print(f'already reported: {title}')
        elif DRY:
            print(f'[DRY] would open: "{title}" assigned to {OWNER}')
        else:
            issue = api(f'/repos/{REPO}/issues', 'POST',
                        {'title': title, 'body': body, 'labels': ['dependencies'], 'assignees': [OWNER]})
            print(f'opened #{issue["number"]}: {title}')

    for e in errors:
        print(f'::error::{e}')
    sys.exit(1 if errors else 0)


if __name__ == '__main__':
    main()
