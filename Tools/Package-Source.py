"""Package reviewable source only; does not build or certify a macOS app.

Usage: python3 Tools/Package-Source.py [--output DIRECTORY]
Uses the current VERSION and rejects missing/mismatched music assets. Excludes
build products, Python caches, SwiftPM state and Git metadata.
"""
from pathlib import Path
import argparse,hashlib,json,os,tempfile,zipfile,importlib.util

def sha(data):return hashlib.sha256(data).hexdigest()

def main():
    source=Path(__file__).resolve().parents[1]
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=source.parent/'Cinder-artifacts')
    args=parser.parse_args();output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    spec=importlib.util.spec_from_file_location('source_validation',source/'Tools/Validate-Source.py')
    validator=importlib.util.module_from_spec(spec);spec.loader.exec_module(validator)
    version=validator.validate(source)['version']
    identity=(source/'Sources/CinderCore/Models.swift').read_text(encoding='utf-8')
    if f'version = "{version}"' not in identity:raise ValueError('Source and public versions differ')
    resources=source/'Sources/CinderApp/Resources'
    manifest=json.loads((resources/'preset-music-v2.json').read_text(encoding='utf-8'))
    expected=['Classic','Balanced','Electronic','Acoustic','POP','Rock','Metal']
    if [p['preset'] for p in manifest['presets']]!=expected:raise ValueError('Expected seven presets')
    for item in manifest['presets']:
        path=resources/f"preset-{item['preset'].lower()}.flac"
        if sha(path.read_bytes())!=item['sha256']:raise ValueError(f'Music checksum failed: {path.name}')
    history=json.loads((resources/'changelog.json').read_text(encoding='utf-8'))
    if history['releases'][0]['version']!=version:raise ValueError('Changelog version differs')
    excluded={'.build','.swiftpm','dist','__pycache__','.git','.DS_Store','AGENTS.md',
              'CHATGPT-HANDOFF.md','NATIVE-VALIDATION.json','DEVELOPMENT-TREE-VALIDATION.json'}
    local_records={'Docs/Audio/DEVICE-VALIDATION.md','Docs/Audio/PRESET-MUSIC-VALIDATION.json'}
    files=sorted(p for p in source.rglob('*') if p.is_file()
                 and not excluded.intersection(p.relative_to(source).parts)
                 and not p.relative_to(source).as_posix().startswith('Docs/History/')
                 and p.relative_to(source).as_posix() not in local_records
                 and p.suffix not in {'.pyc','.pyo'})
    if any(p.is_symlink() for p in files):raise ValueError('Source archives must contain regular files')
    # Avoid archiving an older ZIP if someone chooses an output folder in source.
    if output==source or source in output.parents:raise ValueError('Choose an output directory outside source')
    prefix='Cinder';archive=output/f'Cinder-v{version}-macos-development.zip'
    fd,temp=tempfile.mkstemp(prefix=prefix+'-',suffix='.tmp',dir=output);os.close(fd)
    temp=Path(temp)
    try:
        with zipfile.ZipFile(temp,'w',zipfile.ZIP_DEFLATED) as z:
            for file in files:
                info=zipfile.ZipInfo(prefix+'/'+file.relative_to(source).as_posix())
                info.create_system=3
                executable=file.suffix in {'.command','.sh'}
                info.external_attr=(0o100755 if executable else 0o100644)<<16
                z.writestr(info,file.read_bytes(),compress_type=zipfile.ZIP_DEFLATED)
        with zipfile.ZipFile(temp) as z:
            if z.testzip() is not None:raise ValueError('ZIP integrity failed')
            if len(z.infolist())!=len(files):raise ValueError('ZIP file count differs')
            for file in files:
                name=prefix+'/'+file.relative_to(source).as_posix()
                if sha(z.read(name))!=sha(file.read_bytes()):raise ValueError(f'Archive differs: {name}')
                if file.suffix in {'.command','.sh'} and not ((z.getinfo(name).external_attr>>16)&0o111):
                    raise ValueError(f'Missing executable permission: {name}')
        os.replace(temp,archive)
    finally:
        if temp.exists():temp.unlink()
    digest=sha(archive.read_bytes())
    archive.with_suffix('.zip.sha256').write_text(f'{digest}  {archive.name}\n',encoding='ascii')
    report={'archive':archive.name,'version':version,'kind':'macOS development source only','project_root':prefix,'files':len(files),
            'sha256':digest,'checks':['CRC','every entry matches source','root folder','executable permissions','seven music hashes'],
            'native_mac_build_executed':False}
    archive.with_suffix('.zip.validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(f'PASS: {len(files)} source files, ZIP contents and seven music masters verified.')
    print(archive)

if __name__=='__main__':main()
