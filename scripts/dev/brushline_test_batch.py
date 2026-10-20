"""Run functional Godot suites, retain exact logs and explicit native exceptions."""
from pathlib import Path
import subprocess,json,sys,time
ROOT=Path(__file__).resolve().parents[2]
engine='/Applications/Godot.app/Contents/MacOS/Godot'
items=[]
for path in sorted((ROOT/'tests').glob('*test.gd')):
 if path.stem=='brushline_demo_test':continue
 native=path.stem=='flag_render_test'
 args=[engine]+([] if native else ['--headless'])+['--path',str(ROOT),'--script','res://tests/'+path.name,'--']
 if path.stem!='plate_identity_test':args+=['--test-defaults']
 start=time.monotonic()
 try:
  p=subprocess.run(args,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=360)
  text=p.stdout.decode(errors='replace');code=p.returncode
 except subprocess.TimeoutExpired as e:text=(e.stdout or b'').decode(errors='replace');code=-1
 (ROOT/'logs'/('brushline_'+path.stem+'.log')).write_text(text)
 ok=code==0 and 'SCRIPT ERROR:' not in text and 'FAIL:' not in text and ('0 failures' in text or path.stem=='smoke_test')
 row={'test':path.name,'passed':ok,'exit':code,'seconds':round(time.monotonic()-start,2),'native':native}
 items.append(row);print(json.dumps(row),flush=True)
 (ROOT/'logs/brushline-test-summary.json').write_text(json.dumps(items,indent=2))
sys.exit(not all(r['passed'] for r in items))
