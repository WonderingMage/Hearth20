"""Focused exact-package checks; no real accounts or unrelated eating/casino flows."""
from pathlib import Path
import datetime,hashlib,json,os,subprocess,sys,re
root=Path(__file__).resolve().parents[1]
artifact=json.loads((root/'qa/portable/artifact.json').read_text())
drawing='--drawing' in sys.argv
exe=Path(artifact['exe']);out=root/'qa'/('drawing-release' if drawing else 'items-release');out.mkdir(exist_ok=True)
assert artifact['version']==('0.3.22-beta' if drawing else '0.3.21-beta') and not artifact['debug']
with exe.open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==artifact['sha256']
env_base=os.environ.copy();results=[]
cwd=out/'empty-cwd';cwd.mkdir(exist_ok=True)
headless=['autosave','campaign_saves','beyond_core','map_navigation','map_background','steam_images','preferences_updates']
native=['belongings','sidebar_stability','map_switch_input','map_package_ui','token_picker_input','session_tools_ui','wizard_avatars','wizard_eyes','public_beta']
if drawing:headless.append('token_routes');native.insert(0,'drawing_selection')
for name in headless+native:
    folder=out/name;folder.mkdir(exist_ok=True);env=env_base.copy()
    for key,sub in [('APPDATA','Roaming'),('LOCALAPPDATA','Local')]:
        location=folder/'profile'/sub;location.mkdir(parents=True,exist_ok=True);env[key]=str(location)
    env['H20_QA_EVIDENCE']=str(folder);env['H20_MAP_FIXTURES']=str(root/'qa/map-packages/fixtures')
    args=[str(exe),*(['--headless'] if name in headless else ['--verbose']),'--script',str(root/'source/hearth20/tests'/f'{name}.gd'),'--',str(folder)]
    print('Checking '+name,flush=True)
    try:
        result=subprocess.run(args,cwd=cwd,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8',errors='replace',timeout=180,creationflags=subprocess.CREATE_NO_WINDOW)
        code=result.returncode;log=result.stdout
    except subprocess.TimeoutExpired as exc:code=-1;log=str(exc.stdout)
    (folder/'run.log').write_text(log,encoding='utf-8')
    issues=[line for line in log.splitlines() if line.startswith(('ERROR:','SCRIPT ERROR:','WARNING:'))]
    counts=re.findall(r'(\d+) (?:checks|assertions), (\d+) failures',log)
    fixture=folder/'result.json'
    fixture_data=json.loads(fixture.read_text()) if fixture.exists() else {}
    record={'test':name,'ok':code==0 and not issues,'exit_code':code,'issues':issues,'counts':counts,'fixture':fixture_data}
    results.append(record);(out/'checks.json').write_text(json.dumps({'artifact':{k:artifact[k] for k in ['version','exe','sha256','bytes']},'tests':results,'ok':all(item['ok'] for item in results),'completed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()},indent=2))
    print(json.dumps({k:v for k,v in record.items() if k!='fixture'}),flush=True)
    if not record['ok']:raise SystemExit(1)
