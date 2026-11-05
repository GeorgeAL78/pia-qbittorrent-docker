#!/usr/bin/env python3
"""Automatic qBittorrent releases.

  auto-release.py beta              newest qBittorrent release (pre-releases included)
                                    newer than the beta branch's pin -> bump the pin on
                                    beta, tag it (the tag always contains "beta"), start
                                    the publish workflow and open an issue.
  auto-release.py promote [X.Y.Z]   a stable qBittorrent version (default: beta's pin)
                                    newer than master's -> bump master, update README and
                                    dockerhub/README.md, tag vX.Y.Z and start the publish
                                    workflow, which moves :latest.

Only the qBittorrent pin changes. libtorrent, Boost and Ninja stay with the weekly
component check. The version helpers come from check-components.py.

Env: GITHUB_TOKEN, GITHUB_REPOSITORY, GITHUB_REPOSITORY_OWNER, GITHUB_SERVER_URL.
DRY_RUN=1 prints every change instead of making it.
"""
import base64, gzip, importlib.util, io, os, re, sys, tarfile, urllib.request

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
    text = set_row(text, 'qBittorrent', *qbt)
    text = set_row(text, 'libtorrent', *lt)
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
        body += ['', f'To release it as `:latest`: Actions → **Promote release** → Run workflow '
                     f'({SERVER}/{REPO}/actions/workflows/promote-release.yml). '
                     'Test `:beta` with a VPN first if you want.']
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
    hub_new = re.sub(r'\*\*[^*\n]+\*\* \(latest\)\n- [^\n]*\n',
                     f'**{version}** (latest)\n- Updated to qBittorrent {version} and libtorrent {lt}.\n', hub, count=1)
    if hub_new == hub:
        print('::warning::dockerhub/README.md: "(latest)" entry not found, left as is')
    files = {'Dockerfile': new_master_df, 'README.md': readme, 'dockerhub/README.md': hub_new}
    sha = commit_files('master', files, f'qBittorrent {version}, libtorrent {lt}')
    commit_files('beta', {'README.md': readme, 'dockerhub/README.md': hub_new}, f'Docs: qBittorrent {version}')
    tag_and_publish(tag, sha)
    close_issue(f'qBittorrent {version} is available',
                f'Promoted: **`{tag}`** is being published as `:latest` ({SERVER}/{REPO}/actions/workflows/{PUBLISH}).')


if __name__ == '__main__':
    if len(sys.argv) < 2 or sys.argv[1] not in ('beta', 'promote'):
        sys.exit(__doc__)
    if sys.argv[1] == 'beta':
        cmd_beta()
    else:
        cmd_promote(sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] else None)
