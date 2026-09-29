"""Confirmed monitor changes with a watchdog independent of the desktop shell."""
import pathlib,os,json,subprocess,time,re,uuid,fcntl,math
import hypr_win8_palette as palette
H=pathlib.Path.home()
def run(args):return subprocess.run(args,check=True,capture_output=True,text=True,timeout=12).stdout
def directory():
 p=H/'.local/state/hypr-win8';p.mkdir(parents=True,exist_ok=True);return p
def atomic(path,data):
 palette.atomic(path,json.dumps(data,indent=2)+'\n');path.chmod(0o600)
def lease():
 p=directory()/'display-trial.json';return json.loads(p.read_text()) if p.exists() else {}
def lua(rule):return 'hl.monitor({'+','.join(k+'='+json.dumps(v) for k,v in rule.items())+'})'
def config(rules):return '-- Confirmed Metro display preferences\n'+'\n'.join(lua(r) for _,r in sorted(rules.items()))+'\n'
def current():return json.loads(run(['hyprctl','monitors','-j']))
def rule(m):return dict(output=m['name'],mode=f"{m['width']}x{m['height']}@{m['refreshRate']}",position=f"{m['x']}x{m['y']}",scale=m['scale'],transform=m.get('transform',0))
def apply(r):run(['hyprctl','eval',lua(r)])
def modes(m):
 result=[]
 for value in m.get('availableModes',[]):
  match=re.fullmatch(r'(\d+)x(\d+)@([\d.]+)(?:Hz)?',value)
  if match:result.append(dict(width=int(match[1]),height=int(match[2]),rate=float(match[3])))
 result.append(dict(width=m['width'],height=m['height'],rate=m['refreshRate']))
 return list({(r['width'],r['height'],round(r['rate'],2)):r for r in result}.values())
def query():
 ms=current()
 for m in ms:m['modes']=modes(m)
 print(json.dumps({'monitors':ms,'trial':lease()}))
def test(name,width,height,rate,scale,custom='false'):
 width=int(width);height=int(height);rate=float(rate);scale=float(scale)
 if not (320<=width<=16384 and 200<=height<=16384 and math.isfinite(rate) and 20<=rate<=1000 and math.isfinite(scale) and .5<=scale<=4):raise ValueError('Invalid resolution, refresh rate or scale')
 lock=open(directory()/'display.lock','a');fcntl.flock(lock,fcntl.LOCK_EX)
 if lease().get('status')=='pending':raise ValueError('Confirm or revert the current display trial first')
 m=next((m for m in current() if m['name']==name),None)
 if m is None:raise ValueError('Monitor is no longer connected')
 new=rule(m)
 if custom=='true':
  output=run(['cvt',str(width),str(height),str(rate)])
  match=re.search(r'Modeline\s+"[^"]+"\s+([\d.]+(?:\s+\d+){8}\s+[+-]hsync\s+[+-]vsync)',output,re.I)
  if not match:raise ValueError('CVT could not generate the requested timing')
  new['mode']='modeline '+' '.join(match[1].split())
 else:
  found=next((r for r in modes(m) if r['width']==width and r['height']==height and abs(r['rate']-rate)<.1),None)
  if not found:raise ValueError('Mode is not advertised by the monitor; use Custom mode explicitly')
  new['mode']=f"{width}x{height}@{found['rate']}"
 new['scale']=scale;token=uuid.uuid4().hex
 data=dict(token=token,status='pending',deadline=time.time()+20,old=rule(m),new=new)
 atomic(directory()/'display-trial.json',data)
 try:
  args=['systemd-run','--user','--quiet','--collect','--unit=hypr-win8-display-'+token,'--property=Type=exec','--property=RuntimeMaxSec=45']
  for var in ('HYPRLAND_INSTANCE_SIGNATURE','XDG_RUNTIME_DIR','WAYLAND_DISPLAY'):args+=['--setenv='+var+'='+os.environ.get(var,'')]
  run(args+['python3',str(H/'.local/bin/hypr-win8-backend'),'display-watch',token])
  apply(new)
 except Exception:
  data['status']='reverted';atomic(directory()/'display-trial.json',data);apply(data['old']);raise
 print(json.dumps(data))
def finish(token,keep=False):
 lock=open(directory()/'display.lock','a');fcntl.flock(lock,fcntl.LOCK_EX)
 data=lease()
 if data.get('token')!=token or data.get('status')!='pending':return
 if keep and time.time()<data['deadline']:
  path=H/'.config/hypr-win8/displays.json';rules=json.loads(path.read_text()) if path.exists() else {}
  rules[data['new']['output']]=data['new'];atomic(path,rules)
  script=path.with_suffix('.lua');palette.atomic(script,config(rules));palette.record(H,[str(path.relative_to(H)),str(script.relative_to(H))]);data['status']='confirmed'
 else:apply(data['old']);data['status']='reverted'
 atomic(directory()/'display-trial.json',data)
def watch(token):
 while True:
  data=lease()
  if data.get('token')!=token or data.get('status')!='pending':return
  if time.time()>=data['deadline']:finish(token);return
  time.sleep(.5)
