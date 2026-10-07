"""Validate CI branch/tag intent before building or preparing a release draft.

No branches, tags or releases are created by this script. Uses only Python's
standard library and Git. Run from a committed checkout, locally or in Actions.
"""
from pathlib import Path
import importlib.util
import os
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
VERSION_PATTERN = r'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-(dev(?:\.(0|[1-9]\d*))?|(?:alpha|beta|rc)\.(0|[1-9]\d*)))?'


def build_plan(version, ref, event, base_ref, sha, on_main=False, *, test_release=False,
               intel_experimental=False):
    match = re.fullmatch(VERSION_PATTERN, version)
    if not match or not re.fullmatch(r'[0-9a-f]{40}', sha):
        raise ValueError('Invalid version or commit identity')
    prerelease = match.group(4) is not None
    if ref.startswith('refs/tags/'):
        if event not in {'push', 'workflow_dispatch'}:
            raise ValueError('Release tags require a push or explicit dispatch')
        if prerelease or ref != f'refs/tags/v{version}':
            raise ValueError('Release tag must exactly match a stable VERSION')
        if not on_main:
            raise ValueError('Release commit must already be on origin/main')
        channel = 'release'
        artifact = f'Cinder-v{version}-arm64'
    else:
        if event == 'pull_request':
            if not re.fullmatch(r'refs/pull/[1-9]\d*/merge', ref):
                raise ValueError('Expected a pull request merge ref')
            branch = base_ref
        elif event in {'push', 'workflow_dispatch', 'local'} and ref.startswith('refs/heads/'):
            branch = ref.removeprefix('refs/heads/')
        else:
            raise ValueError('Unsupported build event or ref')
        if branch not in {'dev', 'main'}:
            raise ValueError('Builds target dev or main only')
        if branch == 'dev' and not prerelease:
            raise ValueError('dev requires a development/prerelease version')
        if branch == 'main' and prerelease:
            raise ValueError('main is reserved for reviewed stable versions')
        channel = ('staging' if event == 'workflow_dispatch' else
                   'review' if event == 'pull_request' else
                   'dev' if branch == 'dev' else 'candidate')
        artifact = f'Cinder-{channel}-{version}-{sha[:7]}-arm64'
    result = {'version': version, 'channel': channel, 'artifact': artifact}
    if intel_experimental:
        if event != 'workflow_dispatch' or ref != 'refs/heads/dev':
            raise ValueError('Intel experimental packages require a manual dev build')
        result['intel_artifact'] = f'Cinder-staging-{version}-{sha[:7]}-x86_64-experimental'
    if test_release:
        if event != 'workflow_dispatch' or ref != 'refs/heads/dev':
            raise ValueError('Test release drafts require a manual dev build')
        release_version = '.'.join(match.group(1, 2, 3))
        result['test_tag'] = f'test-{release_version}-{branch}-{sha[:7]}'
    return result


def check_tracked_files(paths):
    local_names = {'AGENTS.md', 'CHATGPT-HANDOFF.md', 'NATIVE-VALIDATION.json',
                   'DEVELOPMENT-TREE-VALIDATION.json'}
    local_records = {'Docs/Audio/DEVICE-VALIDATION.md', 'Docs/Audio/PRESET-MUSIC-VALIDATION.json'}
    if any(Path(path).name in local_names or path.startswith('Docs/History/')
           or path in local_records for path in paths):
        raise ValueError('Local instructions, handoff notes and execution records must remain untracked')


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def main():
    spec = importlib.util.spec_from_file_location('source_validation', ROOT / 'Tools/Validate-Source.py')
    validator = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(validator)
    version = validator.validate(ROOT)['version']
    check_tracked_files(git('ls-files', '-z').split('\0'))
    ref = os.environ.get('GITHUB_REF') or git('symbolic-ref', 'HEAD')
    sha = git('rev-parse', 'HEAD')
    on_main = False
    if ref.startswith('refs/tags/'):
        on_main = subprocess.run(
            ['git', 'merge-base', '--is-ancestor', 'HEAD', 'refs/remotes/origin/main'],
            cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        ).returncode == 0
    result = build_plan(version, ref, os.environ.get('GITHUB_EVENT_NAME', 'local'),
                        os.environ.get('GITHUB_BASE_REF', ''), sha, on_main,
                        test_release=os.environ.get('CINDER_TEST_RELEASE') == 'true',
                        intel_experimental=os.environ.get('CINDER_INTEL_EXPERIMENTAL') == 'true')
    output = ''.join(f'{key}={value}\n' for key, value in result.items())
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as stream:
            stream.write(output)
    print(output, end='')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f'FAIL: {error}', file=sys.stderr)
        sys.exit(1)
