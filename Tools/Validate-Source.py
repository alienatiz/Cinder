"""Portable source/asset checks. This does not execute Swift or certify macOS.

Run with Python 3 from any directory; no third-party modules are required.
"""
from pathlib import Path
import hashlib,json,plistlib,re,string,sys

ROOT=Path(__file__).resolve().parents[1]

def validate(source=ROOT):
    identity_file=(source/'Build-Identity.sh').read_text(encoding='utf-8')
    identity=dict(re.findall(r'^([A-Z_]+)="([^"]+)"$',identity_file,re.M))
    version=(source/'VERSION').read_text(encoding='utf-8').strip()
    match=re.fullmatch(r'((?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*))(?:-(dev(?:\.(?:0|[1-9]\d*))?|(?:alpha|beta|rc)\.(?:0|[1-9]\d*)))?',version)
    if not match:raise ValueError('Use a stable version, -dev, or a numbered dev/alpha/beta/rc version')
    channel=match.group(2).split('.')[0] if match.group(2) else 'stable'
    if identity['RELEASE_CHANNEL']!=channel:raise ValueError('Version and release channel disagree')
    expected_name='Cinder' if channel=='stable' else 'Cinder (Dev)' if channel=='dev' else 'Cinder (Beta)'
    if identity['APP_NAME']!=expected_name:raise ValueError('App name and release channel disagree')
    if version!=identity['PUBLIC_VERSION']:raise ValueError('VERSION and shell identity disagree')
    if not (version==identity['MARKETING_VERSION'] or version.startswith(identity['MARKETING_VERSION']+'-')):
        raise ValueError('Public and bundle marketing versions disagree')
    core=(source/'Sources/CinderCore/Models.swift').read_text(encoding='utf-8')
    for key,value in [('version',version),('build',identity['BUILD_VERSION']),('minimumMacOS',identity['MINIMUM_MACOS']),('releaseChannel',channel)]:
        if f'public static let {key} = "{value}"' not in core:raise ValueError(f'Swift identity mismatch: {key}')
    package=(source/'Package.swift').read_text(encoding='utf-8')
    if f'.macOS("{identity["MINIMUM_MACOS"]}")' not in package:raise ValueError('Deployment target mismatch')
    if identity['TARGET_ARCH']!='arm64':raise ValueError('This development baseline targets arm64')
    build=(source/'Build-App.command').read_text(encoding='utf-8')
    match=re.search(r'<<PLIST\n(.*?)\nPLIST',build,re.S)
    if not match:raise ValueError('Missing Info.plist template')
    plist=plistlib.loads(string.Template(match.group(1)).substitute({**identity,'version':version}).encode('utf-8'))
    for key,value in [('CFBundleShortVersionString',identity['MARKETING_VERSION']),('CFBundleVersion',identity['BUILD_VERSION']),('CinderPublicVersion',version),('LSMinimumSystemVersion',identity['MINIMUM_MACOS'])]:
        if plist[key]!=value:raise ValueError(f'Bundle metadata mismatch: {key}')
    if plist['LSArchitecturePriority']!=['arm64']:raise ValueError('Bundle architecture mismatch')
    resources=source/'Sources/CinderApp/Resources'
    languages=[json.loads((resources/f'lang_{code}.json').read_text(encoding='utf-8')) for code in ['en','ko','jp']]
    if not all(set(language)==set(languages[0]) for language in languages):raise ValueError('Language key sets differ')
    keys=set()
    for file in (source/'Sources/CinderApp').glob('*.swift'):
        keys.update(re.findall(r'\bt\("([^"\\]+)"\)',file.read_text(encoding='utf-8')))
    if keys-set(languages[0]):raise ValueError(f'Missing language keys: {sorted(keys-set(languages[0]))}')
    history=json.loads((resources/'changelog.json').read_text(encoding='utf-8'))['releases']
    if history[0]['version']!=version:raise ValueError('Changelog and public versions disagree')
    if len({row['version'] for row in history})!=len(history):raise ValueError('Duplicate changelog version')
    manifest=json.loads((resources/'preset-music-v2.json').read_text(encoding='utf-8'))
    names=['Classic','Balanced','Electronic','Acoustic','POP','Rock','Metal']
    if [row['preset'] for row in manifest['presets']]!=names:raise ValueError('Expected all seven presets')
    for row in manifest['presets']:
        file=resources/f"preset-{row['preset'].lower()}.flac"
        if hashlib.sha256(file.read_bytes()).hexdigest()!=row['sha256']:raise ValueError(f'Corrupt audio asset: {file.name}')
    for folder in ['Sources','Tests','Tools']:
        for file in (source/folder).rglob('*'):
            if file.suffix not in {'.swift','.py','.c','.h','.command','.sh'}:continue
            text=file.read_text(encoding='utf-8')
            # Reject concrete drive-qualified dependencies, not historical prose.
            if re.search(r'[A-Za-z]:[/\\](?:Users|Program Files|Windows)[/\\]',text):
                raise ValueError(f'Absolute Windows dependency: {file.relative_to(source)}')
    for file in [*source.glob('*.command'),*source.glob('*.sh')]:
        if b'\r' in file.read_bytes():raise ValueError(f'Shell script must use LF: {file.name}')
    for file in ['Setup-Mac.command','Check-Xcode.command','Build-App.command','Build-DMG.command','Build-PKG.command','DEVELOPMENT.md']:
        if not (source/file).is_file():raise ValueError(f'Missing development entry point: {file}')
    return {'version':version,'checks':['identity','deployment','Info.plist','translations','changelog','seven music hashes','portable code paths','shell line endings','development entry points'],
            'native_build_executed':False}

if __name__=='__main__':
    try:
        result=validate()
        print(f"PASS: {result['version']} portable source and asset checks ({len(result['checks'])} groups).")
        print('Swift compilation, XCTest, UI and device audio are not executed by this script.')
    except (ValueError,OSError,KeyError) as error:
        print(f'FAIL: {error}',file=sys.stderr);sys.exit(1)
