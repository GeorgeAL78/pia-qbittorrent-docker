#!/usr/bin/env python3
"""Automatic qBittorrent releases.

  auto-release.py beta              newest qBittorrent release (pre-releases included)
                                    newer than the beta branch's pin -> bump the pin on
                                    beta, tag it (the tag always contains "beta"), start
                                    the publish workflow and open an issue.
  auto-release.py stable            releases :latest when anything in it is out of date:
                                    a newer stable qBittorrent (tag vX.Y.Z), or a newer
                                    libtorrent 2.1.x / Boost / Ninja, a newer Alpine point
                                    release or newer Alpine packages than the published
                                    image has (tag vX.Y.Z-N, a rebuild). Needs docker.
  auto-release.py promote [X.Y.Z]   manual: a stable qBittorrent version (default: beta's
                                    pin) newer than master's -> bump master, update README
                                    and dockerhub/README.md, tag vX.Y.Z and publish.

Nothing is published unless the publish workflow's lint and smoke test pass. While the
previous stable tag has no GitHub release yet (publish running or failed), "stable" waits.
The version helpers come from check-components.py.

Env: GITHUB_TOKEN, GITHUB_REPOSITORY, GITHUB_REPOSITORY_OWNER, GITHUB_SERVER_URL.
DRY_RUN=1 prints every change instead of making it.
"""
import base64, gzip, importlib.util, io, os, re, subprocess, sys, tarfile, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location('check_components', os.path.join(HERE, 'check-components.py'))
cc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(cc)

REPO, OWNER, api = cc.REPO, cc.OWNER, cc.api
DRY = os.environ.get('DRY_RUN') == '1'
SERVER = os.environ.get('GITHUB_SERVER_URL', 'https://github.com')
QBT_REPO = 'qbittorrent/qBittorrent'
QBT_ANY = cc.BETA[0]      # (name, pin regex, repo, tag regex) incl. beta/rc
QBT_STABLE = cc.MASTER[0]
LT_PIN = cc.BETA[1][1]
BOOST = cc.MASTER[2]
IMAGE = 'gjergjk/pia-qbittorrent:latest'
# How each automatically bumped pin is rewritten in a Dockerfile (all occurrences).
BUMPS = {
    'libtorrent': lambda t, o, n: t.replace(f'download/v{o}/libtorrent-rasterbar-{o}.',
                                            f'download/v{n}/libtorrent-rasterbar-{n}.'),
    'Boost': lambda t, o, n: t.replace(f'boost-{o}', f'boost-{n}'),       # URL and BOOST_INCLUDEDIR
    'Ninja': lambda t, o, n: t.replace(f'tags/v{o}.tar', f'tags/v{n}.tar'),
}
PUBLISH = 'docker-publish.yml'
PKG_ROWS = [('openvpn', 'OpenVPN'), ('wireguard-tools', 'WireGuard'), ('iptables', 'IPTables')]


def say(msg):
    print(('[DRY] ' if DRY else '') + msg)


# ---------- repository access ----------
def get_file(path, ref):
    d = api(f'/repos/{REPO}/contents/{path}?ref={ref}')
    return base64.b64decode(d['content']).decode('utf-8')


def branch_head(branch):
    return api(f'/repos/{REPO}/git/ref/heads/{branch}')['object']['sha']


def commit_files(branch, files, message):
    """One commit with all files on branch. Returns the commit sha."""
    if DRY:
        say(f'commit to {branch}: {message} ({", ".join(files)})')
        return 'dry-run-sha'
    head = branch_head(branch)
    base_tree = api(f'/repos/{REPO}/git/commits/{head}')['tree']['sha']
    tree = []
    for path, text in files.items():
        blob = api(f'/repos/{REPO}/git/blobs', 'POST', {'content': text, 'encoding': 'utf-8'})
        tree.append({'path': path, 'mode': '100644', 'type': 'blob', 'sha': blob['sha']})
    new_tree = api(f'/repos/{REPO}/git/trees', 'POST', {'base_tree': base_tree, 'tree': tree})['sha']
    commit = api(f'/repos/{REPO}/git/commits', 'POST', {'message': message, 'tree': new_tree, 'parents': [head]})['sha']
    api(f'/repos/{REPO}/git/refs/heads/{branch}', 'PATCH', {'sha': commit})
    print(f'committed {commit[:7]} to {branch}: {message}')
    return commit


def tag_exists(tag):
    try:
        api(f'/repos/{REPO}/git/ref/tags/{tag}')
        return True
    except Exception:
        return False


def tag_and_publish(tag, sha):
    if DRY:
        say(f'tag {tag} and start {PUBLISH} on it')
        return
    api(f'/repos/{REPO}/git/refs', 'POST', {'ref': f'refs/tags/{tag}', 'sha': sha})
    # A tag pushed with GITHUB_TOKEN does not trigger "on: push"; a dispatch does.
    api(f'/repos/{REPO}/actions/workflows/{PUBLISH}/dispatches', 'POST', {'ref': tag})
    print(f'tagged {tag} and started {PUBLISH}')


def issue_by_title(title):
    for page in range(1, 11):
        batch = api(f'/repos/{REPO}/issues?state=all&labels=dependencies&per_page=100&page={page}')
        for i in batch:
            if i['title'] == title:
                return i
        if len(batch) < 100:
            break
    return None


def open_issue(title, body):
    found = issue_by_title(title)
    if found:
        if found['state'] == 'open' and not DRY:
            api(f'/repos/{REPO}/issues/{found["number"]}/comments', 'POST', {'body': body})
        say(f'issue already exists: #{found["number"]} {title}')
        return
    if DRY:
        say(f'open issue "{title}"')
        return
    i = api(f'/repos/{REPO}/issues', 'POST', {'title': title, 'body': body,
                                              'labels': ['dependencies'], 'assignees': [OWNER]})
    print(f'opened #{i["number"]}: {title}')


def close_issue(title, comment):
    found = issue_by_title(title)
    if not found or found['state'] != 'open':
        return
    if DRY:
        say(f'close issue #{found["number"]}')
        return
    api(f'/repos/{REPO}/issues/{found["number"]}/comments', 'POST', {'body': comment})
    api(f'/repos/{REPO}/issues/{found["number"]}', 'PATCH', {'state': 'closed'})
    print(f'closed #{found["number"]}')


# ---------- pins and docs ----------
def pin(text, pin_re, name):
    errors = []
    value = cc.one_pin(text, pin_re, name, 'Dockerfile', errors)
    if value is None:
        sys.exit('::error::' + errors[0])
    return value


def set_qbt_pin(text, old, new):
    old_s, new_s = f'tarball/release-{old} ', f'tarball/release-{new} '
    if text.count(old_s) != 1:
        sys.exit(f'::error::expected exactly one "{old_s}" in the Dockerfile')
    return text.replace(old_s, new_s)


def beta_tag(version):
    m = re.fullmatch(r'(\d+\.\d+\.\d+)(beta|rc)?(\d+)?', version)
    if not m:
        sys.exit(f'::error::unexpected qBittorrent version {version}')
    base, stage, n = m.groups()
    if stage == 'beta':
        tag = f'v{base}-beta{n}-1'
    elif stage == 'rc':
        tag = f'v{base}-rc{n}-beta-1'
    else:
        tag = f'v{base}-beta-1'
    assert 'beta' in tag, tag           # a tag without "beta" would move :latest
    return tag


def alpine_packages(dockerfile):
    m = re.search(r'^FROM alpine:(\d+\.\d+)', dockerfile, re.M)
    if not m:
        return {}
    found = {}
    for repo in ('main', 'community'):
        url = f'https://dl-cdn.alpinelinux.org/alpine/v{m[1]}/{repo}/x86_64/APKINDEX.tar.gz'
        try:
            data = urllib.request.urlopen(url, timeout=60).read()
            with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as t:
                index = t.extractfile('APKINDEX').read().decode('utf-8', 'replace')
        except Exception as e:
            print(f'::warning::Alpine index {repo} not readable: {e}')
            continue
        for block in index.split('\n\n'):
            f = dict(l.split(':', 1) for l in block.splitlines() if len(l) > 1 and l[1] == ':')
            if f.get('P') in dict(PKG_ROWS):
                found[f['P']] = re.sub(r'-r\d+$', '', f['V'])
    return found


def set_row(text, name, stable, beta):
    rx = re.compile(r'^\| ' + re.escape(name) + r' \| [^|]* \| [^|]* \|$', re.M)
    if len(rx.findall(text)) != 1:
        return text
    beta_col = 'same' if beta == stable else beta
    return rx.sub(f'| {name} | {stable} | {beta_col} |', text)


def update_tables(text, master_df, beta_df):
    lt = (pin(master_df, LT_PIN, 'libtorrent'), pin(beta_df, LT_PIN, 'libtorrent'))
    qbt = (pin(master_df, QBT_ANY[1], 'qBittorrent'), pin(beta_df, QBT_ANY[1], 'qBittorrent'))
    boost = (pin(master_df, BOOST[1], 'Boost'), pin(beta_df, BOOST[1], 'Boost'))
    text = set_row(text, 'qBittorrent', *qbt)
    text = set_row(text, 'libtorrent', *lt)
    text = set_row(text, 'Boost', *boost)
    pkgs = alpine_packages(master_df)
    for pkg, label in PKG_ROWS:
        if pkgs.get(pkg):
            text = set_row(text, label, pkgs[pkg], pkgs[pkg])
    return text


def min_libtorrent(version):
    try:
        cm = urllib.request.urlopen(f'https://raw.githubusercontent.com/{QBT_REPO}/release-{version}/CMakeLists.txt',
                                    timeout=30).read().decode()
        m = re.search(r'set\(minLibtorrentVersion ([\d.]+)\)', cm)
        return m[1] if m else None
    except Exception:
        return None


# ---------- commands ----------
def cmd_beta():
    beta_df = get_file('Dockerfile', 'beta')
    master_df = get_file('Dockerfile', 'master')
    pinned = pin(beta_df, QBT_ANY[1], 'qBittorrent')
    found = cc.latest(QBT_REPO, QBT_ANY[3], True)
    if not found:
        sys.exit('::error::no qBittorrent release found')
    newest, url = found
    if cc.key(newest) <= cc.key(pinned):
        print(f'beta: qBittorrent {pinned} is current (newest release {newest})')
        return
    tag = beta_tag(newest)
    if tag_exists(tag):
        print(f'beta: {tag} already exists, nothing to do')
        return
    print(f'beta: qBittorrent {pinned} -> {newest}, tag {tag}')
    new_beta_df = set_qbt_pin(beta_df, pinned, newest)
    master_readme = get_file('README.md', 'master')
    readme = update_tables(master_readme, master_df, new_beta_df)
    sha = commit_files('beta', {'Dockerfile': new_beta_df, 'README.md': readme}, f'Beta: qBittorrent {newest}')
    if readme != master_readme:
        commit_files('master', {'README.md': readme}, f'README: beta is qBittorrent {newest}')
    tag_and_publish(tag, sha)

    stable = re.fullmatch(r'\d+\.\d+\.\d+', newest) is not None
    lt_pinned = pin(new_beta_df, LT_PIN, 'libtorrent')
    lt_min = min_libtorrent(newest)
    runs = f'{SERVER}/{REPO}/actions/workflows/{PUBLISH}'
    body = [f'qBittorrent **{newest}** was released: {url}', '',
            f'It is being built automatically as **`{tag}`** and published as **`:beta`** '
            f'once the build and smoke test pass ([publish runs]({runs})). `:latest` is unchanged.', '',
            f'libtorrent pinned: **{lt_pinned}**; qBittorrent {newest} needs at least **{lt_min or "unknown"}**. '
            'Library versions of the official builds: https://www.qbittorrent.org/download']
    if stable:
        body += ['', 'As a stable release it is also released as `:latest` automatically, '
                     'in the same run, once its build and smoke test pass.']
    open_issue(f'qBittorrent {newest} is available' + ('' if stable else ' (beta)'), '\n'.join(body))


def cmd_promote(version):
    master_df = get_file('Dockerfile', 'master')
    beta_df = get_file('Dockerfile', 'beta')
    current = pin(master_df, QBT_STABLE[1], 'qBittorrent')
    version = version or pin(beta_df, QBT_ANY[1], 'qBittorrent')
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        sys.exit(f'::error::{version} is not a stable qBittorrent version - only stable versions go to :latest')
    if cc.key(version) <= cc.key(current):
        sys.exit(f'::error::master already has qBittorrent {current}; {version} is not newer')
    released = [r for r in cc.releases(QBT_REPO) if r['tag_name'] == f'release-{version}' and not r['prerelease']]
    if not released:
        sys.exit(f'::error::qBittorrent {version} is not a published stable release')
    tag = f'v{version}'
    assert 'beta' not in tag
    if tag_exists(tag):
        sys.exit(f'::error::{tag} already exists')
    print(f'promote: qBittorrent {current} -> {version}, tag {tag}')

    new_master_df = set_qbt_pin(master_df, current, version)
    lt = pin(new_master_df, LT_PIN, 'libtorrent')
    readme = update_tables(get_file('README.md', 'master'), new_master_df, beta_df)
    hub = update_tables(get_file('dockerhub/README.md', 'master'), new_master_df, beta_df)
    hub_new = set_whats_new(hub, version, f'Updated to qBittorrent {version} and libtorrent {lt}.')
    files = {'Dockerfile': new_master_df, 'README.md': readme, 'dockerhub/README.md': hub_new}
    sha = commit_files('master', files, f'qBittorrent {version}, libtorrent {lt}')
    commit_files('beta', {'README.md': readme, 'dockerhub/README.md': hub_new}, f'Docs: qBittorrent {version}')
    tag_and_publish(tag, sha)
    close_issue(f'qBittorrent {version} is available',
                f'Promoted: **`{tag}`** is being published as `:latest` ({SERVER}/{REPO}/actions/workflows/{PUBLISH}).')


def set_whats_new(hub, heading, line):
    """Replace the one-line '(latest)' entry of dockerhub/README.md."""
    new = re.sub(r'\*\*[^*\n]+\*\* \(latest\)\n- [^\n]*\n',
                 lambda _: f'**{heading}** (latest)\n- {line}\n', hub, count=1)
    if new == hub and f'**{heading}** (latest)\n- {line}\n' not in hub:
        print('::warning::dockerhub/README.md: "(latest)" entry not found, left as is')
    return new


# ---------- stable (:latest) ----------
STABLE_TAG = re.compile(r'v(\d+\.\d+\.\d+)(?:-(\d+))?')


def stable_tags():
    """[(sort key, tag, qBittorrent version, fix number)] for vX.Y.Z and vX.Y.Z-N tags."""
    out, page = [], 1
    while page <= 10:
        batch = api(f'/repos/{REPO}/git/matching-refs/tags/v?per_page=100&page={page}') or []
        for r in batch:
            t = r['ref'].rsplit('/', 1)[-1]
            m = STABLE_TAG.fullmatch(t)
            if m:
                out.append((cc.key(m[1]) + (int(m[2] or 0),), t, m[1], int(m[2] or 0)))
        if len(batch) < 100:
            break
        page += 1
    return sorted(out)


def unpublished_tag():
    """The newest stable tag when it has no GitHub release yet (publish running or
    failed), else None. A release is created only after the image is published."""
    tags = stable_tags()
    if not tags:
        return None
    newest = tags[-1][1]
    try:
        released = api(f'/repos/{REPO}/releases/latest')['tag_name']
    except Exception:
        released = None
    return None if newest == released else newest


def publish_run(tag):
    """Latest publish run for a tag: (status, conclusion, url) or None."""
    runs = api(f'/repos/{REPO}/actions/workflows/{PUBLISH}/runs?branch={tag}&per_page=5') or {}
    runs = runs.get('workflow_runs') or []
    if not runs:
        return None
    r = runs[0]
    return r['status'], r['conclusion'], r['html_url']


def docker(*args, timeout=900):
    return subprocess.run(['docker', *args], capture_output=True, text=True,
                          timeout=timeout, check=True).stdout


def image_state(branch):
    """Alpine release of the published image, of alpine:<branch> today, and the image's
    packages that Alpine has newer builds of."""
    docker('pull', '-q', IMAGE)
    docker('pull', '-q', f'alpine:{branch}')
    out = docker('run', '--rm', '--user', '0', '--entrypoint', 'sh', IMAGE, '-c',
                 'cat /etc/alpine-release; apk update -q >/dev/null && apk version -l "<"')
    lines = out.splitlines()
    have = lines[0].strip()
    outdated = []
    for l in lines[1:]:
        m = re.match(r'(\S+?)-\d\S*-r\d+\s+<\s+(\S+)', l.strip())
        if m:
            outdated.append(f'{m[1]} {m[2]}')
    base = docker('run', '--rm', f'alpine:{branch}', 'cat', '/etc/alpine-release').strip()
    if not re.fullmatch(r'\d+\.\d+\.\d+', have) or not re.fullmatch(r'\d+\.\d+\.\d+', base):
        sys.exit(f'::error::unexpected Alpine versions: image "{have}", base "{base}"')
    return have, base, outdated


def cmd_stable():
    pending = unpublished_tag()
    if pending:
        run = publish_run(pending)
        if run and run[0] != 'completed':
            print(f'stable: {pending} is still publishing ({run[2]}) - waiting')
            return
        where = run[2] if run else f'{SERVER}/{REPO}/actions/workflows/{PUBLISH}'
        print(f'::warning::stable: {pending} has no release (publish {run[1] if run else "never started"}) - '
              'not releasing anything else until it is fixed')
        open_issue(f'Release {pending} did not publish',
                   f'**`{pending}`** was tagged but its image was not published, so `:latest` did not move '
                   f'and automatic releases are paused until this is resolved.\n\nPublish run: {where}\n\n'
                   'Fix the cause and re-run the publish workflow on the tag, or delete the tag.')
        return

    master_df = get_file('Dockerfile', 'master')
    beta_df = get_file('Dockerfile', 'beta')
    new_df, new_beta_df = master_df, beta_df
    changes, closes = [], []

    current = pin(master_df, QBT_STABLE[1], 'qBittorrent')
    found = cc.latest(QBT_REPO, QBT_STABLE[3], False)
    qbt = current
    if found and cc.key(found[0]) > cc.key(current):
        qbt = found[0]
        new_df = set_qbt_pin(new_df, current, qbt)
        closes.append(f'qBittorrent {qbt} is available')
        print(f'stable: qBittorrent {current} -> {qbt}')

    for name, pin_re, repo, tag_re in cc.MASTER[1:]:          # libtorrent 2.1.x, Boost, Ninja
        old = pin(new_df, pin_re, name)
        newest = cc.latest(repo, tag_re, False)
        if not newest or cc.key(newest[0]) <= cc.key(old):
            continue
        new = newest[0]
        new_df = BUMPS[name](new_df, old, new)
        if pin(new_df, pin_re, name) != new:
            sys.exit(f'::error::could not rewrite the {name} pin {old} -> {new}')
        # Beta keeps the same Boost/Ninja/libtorrent as master unless it deliberately differs.
        beta_pin = re.findall(pin_re if name != 'libtorrent' else LT_PIN, new_beta_df)
        if beta_pin and beta_pin[0] == old:
            new_beta_df = BUMPS[name](new_beta_df, old, new)
        changes.append(f'{name} {new}')
        closes.append(f'{name} {new} is available')
        print(f'stable: {name} {old} -> {new}')

    branch = re.search(r'^FROM alpine:(\d+\.\d+)', master_df, re.M)[1]
    have, base, outdated = image_state(branch)
    print(f'stable: image Alpine {have}, alpine:{branch} is {base}; {len(outdated)} newer packages'
          + (f': {", ".join(outdated)}' if outdated else ''))
    if cc.key(base) > cc.key(have):
        changes.append(f'Alpine {base}')
    if outdated:
        changes.append('current Alpine packages')

    if qbt == current and not changes:
        print('stable: :latest is up to date')
        return

    if qbt != current:
        tag, heading = f'v{qbt}', qbt
        lt = pin(new_df, LT_PIN, 'libtorrent')
        line = f'Updated to qBittorrent {qbt} and libtorrent {lt}.'
        message = f'qBittorrent {qbt}, libtorrent {lt}'
    else:
        n = max([t[3] for t in stable_tags() if t[2] == qbt] or [0]) + 1
        tag, heading = f'v{qbt}-{n}', f'{qbt}-{n}'
        what = changes[0] if len(changes) == 1 else ', '.join(changes[:-1]) + ' and ' + changes[-1]
        line = f'Rebuilt with {what}.'
        message = f'Rebuild with {what}'
    assert 'beta' not in tag
    if tag_exists(tag):
        sys.exit(f'::error::{tag} already exists')
    print(f'stable: releasing {tag} - {line}')

    readme = update_tables(get_file('README.md', 'master'), new_df, new_beta_df)
    hub = set_whats_new(update_tables(get_file('dockerhub/README.md', 'master'), new_df, new_beta_df),
                        heading, line)
    files = {'README.md': readme, 'dockerhub/README.md': hub}
    if new_df != master_df:
        files['Dockerfile'] = new_df
    sha = commit_files('master', files, message)
    beta_files = {'README.md': readme, 'dockerhub/README.md': hub}
    if new_beta_df != beta_df:
        beta_files['Dockerfile'] = new_beta_df
    commit_files('beta', beta_files, f'Docs: {heading}' if new_beta_df == beta_df else f'{message} (beta)')
    tag_and_publish(tag, sha)

    note = f'Included in **`{tag}`**, being published as `:latest` ({SERVER}/{REPO}/actions/workflows/{PUBLISH}).'
    for title in closes:
        close_issue(title, note)
    if outdated or cc.key(base) > cc.key(have):
        for i in api(f'/repos/{REPO}/issues?state=open&labels=dependencies&per_page=100') or []:
            if re.fullmatch(r'(OpenVPN|WireGuard tools|iptables|Qt6) \S+ is available', i['title']):
                close_issue(i['title'], note)


if __name__ == '__main__':
    if len(sys.argv) < 2 or sys.argv[1] not in ('beta', 'stable', 'promote'):
        sys.exit(__doc__)
    if sys.argv[1] == 'beta':
        cmd_beta()
    elif sys.argv[1] == 'stable':
        cmd_stable()
    else:
        cmd_promote(sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None)
