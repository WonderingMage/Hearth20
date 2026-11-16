"""Items, journals and reconnection across three isolated authenticated localhost peers."""
from pathlib import Path
import json,os,secrets,subprocess,time,sys,hashlib
root=Path(__file__).resolve().parents[1]
external=len(sys.argv)>1
out=root/'qa'/('drawing-release/item-network' if '--drawing' in sys.argv else 'items-release/network' if external else 'belongings-network');out.mkdir(parents=True,exist_ok=True)
for file in list(out.glob('*.ready'))+list(out.glob('*.json'))+list(out.glob('invitation.txt')):file.unlink()
engine=r'C:\Users\fstre\AppData\Local\HearthtableCodexTools\Godot-4.5.1\bin\Godot_v4.5.1-stable_win64_console.exe'
if external:engine=str(Path(sys.argv[1]).resolve())
cwd=out/'empty-cwd';cwd.mkdir(exist_ok=True)
port=36000+secrets.randbelow(2000);processes=[]
try:
    for role in ['host','A','B']:
        env=os.environ.copy()
        for key,sub in [('APPDATA','Roaming'),('LOCALAPPDATA','Local')]:
            folder=out/'profiles'/role/sub;folder.mkdir(parents=True,exist_ok=True);env[key]=str(folder)
        log=(out/(role+'.log')).open('w',encoding='utf-8')
        script=str(root/'source/hearth20/tests/belongings_network.gd') if external else 'res://hearth20/tests/belongings_network.gd'
        process=subprocess.Popen([engine,'--headless',*([] if external else ['--path',str(root/'source')]),'--script',script,'--',role,str(port),str(out)],cwd=cwd,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        processes.append((role,process,log))
    deadline=time.monotonic()+80
    while any(p.poll() is None for _,p,_ in processes) and time.monotonic()<deadline:time.sleep(.2)
    results=[]
    for role,p,log in processes:
        if p.poll() is None:p.terminate();p.wait(5)
        log.close();file=out/(role+'.json')
        result=json.loads(file.read_text()) if file.exists() else {'role':role,'checks':0,'errors':['Process failed to finish; see '+role+'.log']}
        result['exit_code']=p.returncode
        if any(line.startswith(('ERROR:','SCRIPT ERROR:','WARNING:')) for line in (out/(role+'.log')).read_text().splitlines()) and not result['errors']:result['errors'].append('Engine error/warning in log')
        results.append(result)
    ok=all(not r['errors'] and r['exit_code']==0 for r in results)
    (out/'result.json').write_text(json.dumps({'backend':'localhost ENet; real authenticated RPCs; no Steam/microphone','ok':ok,'results':results,'exe':engine if external else None,'sha256':hashlib.sha256(Path(engine).read_bytes()).hexdigest() if external else None},indent=2))
    print(json.dumps(results,indent=2));raise SystemExit(0 if ok else 1)
finally:
    for _,p,log in processes:
        if p.poll() is None:p.terminate();p.wait(5)
        if not log.closed:log.close()
