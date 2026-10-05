#!/usr/bin/env python3
"""Compare the component versions pinned in the Dockerfile with the latest
upstream releases, and open one issue per newer version (assigned to the
repository owner). Dependabot cannot see these pins; the Alpine base image
is covered by Dependabot's docker ecosystem instead.

Env: GITHUB_TOKEN, GITHUB_REPOSITORY, GITHUB_REPOSITORY_OWNER.
DRY_RUN=1 prints what would be opened instead of opening it.
"""
import json, os, re, sys, urllib.request

API = 'https://api.github.com'
TOKEN = os.environ.get('GITHUB_TOKEN', '')
REPO = os.environ.get('GITHUB_REPOSITORY', 'GeorgeAL78/pia-qbittorrent-docker')
OWNER = os.environ.get('GITHUB_REPOSITORY_OWNER', REPO.split('/')[0])
DRY = os.environ.get('DRY_RUN') == '1'
DOCKERFILE = sys.argv[1] if len(sys.argv) > 1 else 'Dockerfile'


def api(path, method='GET', body=None):
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None)
    req.add_header('Accept', 'application/vnd.github+json')
    if TOKEN:
        req.add_header('Authorization', 'Bearer ' + TOKEN)
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def releases(repo):
    out, page = [], 1
    while page <= 5:
        batch = api(f'/repos/{repo}/releases?per_page=100&page={page}')
        out += [r for r in batch if not r['draft'] and not r['prerelease']]
        if len(batch) < 100:
            break
        page += 1
    return out


def key(v):
    """'1.91.0-1' -> (1, 91, 0, 1); '5.2.4' -> (5, 2, 4, 0)."""
    m = re.fullmatch(r'(\d+)\.(\d+)\.(\d+)(?:-(\d+))?', v)
    return (int(m[1]), int(m[2]), int(m[3]), int(m[4] or 0)) if m else None


def latest(repo, tag_re):
    best = None
    for r in releases(repo):
        m = re.fullmatch(tag_re, r['tag_name'])
        if m and key(m[1]) and (best is None or key(m[1]) > key(best[0])):
            best = (m[1], r['html_url'])
    return best


# name, pin regex in the Dockerfile, upstream repo, release-tag regex
COMPONENTS = [
    ('qBittorrent', r'qBittorrent/tarball/release-(\d+\.\d+\.\d+)\b',
     'qbittorrent/qBittorrent', r'release-(\d+\.\d+\.\d+)'),
    # Deliberately tracked on the 2.0.x series only.
    ('libtorrent', r'libtorrent/releases/download/v(2\.0\.\d+)/',
     'arvidn/libtorrent', r'v(2\.0\.\d+)'),
    ('Boost', r'boost/releases/download/boost-(\d+\.\d+\.\d+(?:-\d+)?)/',
     'boostorg/boost', r'boost-(\d+\.\d+\.\d+(?:-\d+)?)'),
    ('Ninja', r'ninja/archive/refs/tags/v(\d+\.\d+\.\d+)\.tar',
     'ninja-build/ninja', r'v(\d+\.\d+\.\d+)'),
]


def main():
    dockerfile = open(DOCKERFILE, encoding='utf-8').read()
    existing = set()
    page = 1
    while page <= 10:
        batch = api(f'/repos/{REPO}/issues?state=all&labels=dependencies&per_page=100&page={page}')
        existing |= {i['title'] for i in batch}
        if len(batch) < 100:
            break
        page += 1

    failed = False
    for name, pin_re, repo, tag_re in COMPONENTS:
        pins = set(re.findall(pin_re, dockerfile))
        if len(pins) != 1:
            print(f'::error::{name}: expected exactly one pin in {DOCKERFILE}, found {sorted(pins) or "none"}')
            failed = True
            continue
        pinned = pins.pop()
        found = latest(repo, tag_re)
        if not found:
            print(f'::error::{name}: no matching release found in {repo}')
            failed = True
            continue
        newest, url = found
        if key(newest) <= key(pinned):
            print(f'{name}: {pinned} is current')
            continue
        title = f'{name} {newest} is available'
        if title in existing:
            print(f'{name}: {newest} available, issue already exists')
            continue
        body = (f'The Dockerfile pins {name} **{pinned}**; the latest release is '
                f'**{newest}**.\n\n{url}')
        if DRY:
            print(f'[DRY] would open: "{title}" assigned to {OWNER}')
            continue
        issue = api(f'/repos/{REPO}/issues', 'POST',
                    {'title': title, 'body': body, 'labels': ['dependencies'], 'assignees': [OWNER]})
        print(f'{name}: opened #{issue["number"]} "{title}"')

    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
