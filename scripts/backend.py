#!/usr/bin/env python3
import os,sys,json,time,pathlib,subprocess,shutil,shlex
import hypr_win8_palette as palette
H=pathlib.Path.home()
def call(args,**kw):return subprocess.run(args,check=True,**kw)
def notify(text):subprocess.run(['notify-send','-a','Metro',text],check=False)
def metrics():
 previous=None
 while True:
  nums=list(map(int,pathlib.Path('/proc/stat').read_text().splitlines()[0].split()[1:]));total=sum(nums);idle=nums[3]+nums[4];cpu=0
  if previous and total>previous[0]:cpu=round(100*(1-(idle-previous[1])/(total-previous[0])))
  previous=(total,idle);mem={l.split(':')[0]:int(l.split()[1]) for l in pathlib.Path('/proc/meminfo').read_text().splitlines()}
  temps=[]
  for p in pathlib.Path('/sys/class/hwmon').glob('hwmon*/temp*_input'):
   try:
    n=p.parent.joinpath('name').read_text().strip()
    if n in ('k10temp','coretemp','zenpower'):temps.append(int(p.read_text())/1000)
   except (OSError,ValueError):pass
  backs=list(pathlib.Path('/sys/class/backlight').glob('*'));brightness=None
  if backs:
   try:brightness=round(100*int((backs[0]/'brightness').read_text())/int((backs[0]/'max_brightness').read_text()))
   except (OSError,ValueError,ZeroDivisionError):pass
  print(json.dumps({'cpu':cpu,'ram':round(100*(1-mem['MemAvailable']/mem['MemTotal'])),'temperature':round(max(temps)) if temps else None,'brightness':brightness}),flush=True);time.sleep(2)
def app_catalog():
 from gi.repository import Gio,GioUnix
 out=[]
 for a in Gio.AppInfo.get_all():
  if not isinstance(a,GioUnix.DesktopAppInfo) or not a.should_show():continue
  out.append({'id':a.get_id(),'name':a.get_display_name(),'genericName':a.get_locale_string('GenericName') or '',
              'icon':a.get_string('Icon') or 'application-x-executable','categories':(a.get_categories() or '').strip(';').split(';'),
              'keywords':list(a.get_keywords() or []),'runInTerminal':a.get_boolean('Terminal')})
 return sorted(out,key=lambda a:a['name'].casefold())
def apps_watch():
 from gi.repository import Gio,GLib
 def emit():print(json.dumps(app_catalog(),ensure_ascii=False),flush=True);return False
 pending=[0]
 def changed(monitor):
  if pending[0]:GLib.source_remove(pending[0])
  def refresh():pending[0]=0;return emit()
  pending[0]=GLib.timeout_add(350,refresh)
 emit();monitor=Gio.AppInfoMonitor.get();monitor.connect('changed',changed);GLib.MainLoop().run()
def desktop_app(identifier):
 from gi.repository import GioUnix
 for name in [identifier+'.desktop',identifier]:
  try:
   app=GioUnix.DesktopAppInfo.new(name)
   if app:return app
  except TypeError:pass
 raise RuntimeError('Desktop entry not found: '+identifier)
def inspect_entry(identifier):
 app=desktop_app(identifier)
 print(json.dumps({'name':app.get_name(),'file':app.get_filename(),'terminal':app.get_boolean('Terminal')}))
def launch(identifier):
 from gi.repository import GLib
 app=desktop_app(identifier)
 if app.get_boolean('Terminal'):
  ok,argv=GLib.shell_parse_argv(app.get_string('Exec'))
  expanded=[]
  for a in argv:
   if a=='%i':
    icon=app.get_string('Icon')
    if icon:expanded+=['--icon',icon]
   elif a=='%c':expanded.append(app.get_name())
   elif a=='%k':expanded.append(app.get_filename())
   elif a not in ('%f','%F','%u','%U','%d','%D','%n','%N','%v','%m'):expanded.append(a.replace('%%','%'))
  subprocess.Popen(['kitty','-e']+expanded,cwd=app.get_string('Path') or str(H),start_new_session=True)
 else:app.launch([],None)
def clipboard_list():
 p=call(['cliphist','list'],capture_output=True,text=True)
 print(json.dumps([{'id':line.split('\t',1)[0],'text':line.split('\t',1)[-1]} for line in p.stdout.splitlines()[:150]],ensure_ascii=False))
def clipboard_copy(identifier):
 if not identifier.isdigit():raise ValueError('Invalid clipboard id')
 p=call(['cliphist','decode'],input=identifier.encode(),capture_output=True);call(['wl-copy'],input=p.stdout)
def image_path(value):
 from urllib.parse import urlparse,unquote
 if value.startswith('file:'):
  url=urlparse(value)
  if url.netloc not in ('','localhost'):raise ValueError('Only local images are supported')
  value=unquote(url.path)
 p=pathlib.Path(value).expanduser().resolve(strict=True)
 if not p.is_file() or not os.access(p,os.R_OK):raise ValueError('Image file is not readable')
 # Decoding validates the selected image, including SVG and EXIF-oriented photos.
 try:palette.sample(p)
 except Exception as e:raise ValueError("Unsupported or invalid image") from e
 return p
def theme(mode=None,accent=None,wallpaper=None):
 t=json.loads((H/'.config/hypr-win8/theme.json').read_text());t=palette.prepare(t)
 if mode:t['mode']=('light' if t.get('mode')=='dark' else 'dark') if mode=='toggle' else mode
 if accent:
  for value in t['palettes'].values():value['accent']=accent;value['onAccent']=palette.text_on(accent)
  t['autoPalette']=False
 if wallpaper:return globals()['wallpaper'](wallpaper)
 palette.apply(t,H)
def wallpaper(value,target='desktop'):
 p=image_path(value);t=json.loads((H/'.config/hypr-win8/theme.json').read_text())
 if target=='desktop':
  t['wallpaper']=str(p);t['wallpaperHistory']=([str(p)]+[x for x in t.get('wallpaperHistory',[]) if x!=str(p)])[:9]
  t=palette.prepare(t,p);palette.apply(t,H)
 elif target=='lock':
  palette.lock_image(p,H/'.config/hypr-win8/lock-wallpaper.png');t['lockWallpaper']=str(p)
  palette.atomic(H/'.config/hypr-win8/theme.json',json.dumps(t,ensure_ascii=False,indent=2)+'\n');palette.record(H,['.config/hypr-win8/lock-wallpaper.png','.config/hypr-win8/theme.json'])
 else:raise ValueError('Unknown wallpaper target')
 print(str(p))
def custom_color(role,value):
 t=json.loads((H/'.config/hypr-win8/theme.json').read_text());palette.apply(palette.custom(t,role,value),H)
def theme_option(key,value):
 p=H/'.config/hypr-win8/theme.json';t=json.loads(p.read_text())
 if key=='wallpaperFit' and value in ('fill','fit','stretch'):t[key]=value
 elif key=='autoPalette' and value in ('true','false'):
  t[key]=value=='true'
  if t[key]:
   path=t.get('wallpaper','metro-blue.svg');path=path if path.startswith('/') else str(H/'.local/share/hypr-win8-dots/assets/wallpapers'/path)
   t=palette.prepare(t,path)
 else:raise ValueError('Invalid theme option')
 palette.apply(t,H)
def language(code):
 languages={'ru':'ru_RU.UTF-8','en':'en_US.UTF-8'}
 if code not in languages:raise ValueError('Unsupported interface language')
 t=json.loads((H/'.config/hypr-win8/theme.json').read_text());t['language']=code
 palette.atomic(H/'.config/hypr-win8/theme.json',json.dumps(t,ensure_ascii=False,indent=2)+'\n')
 locale=languages[code];rel='.config/environment.d/60-hypr-win8-locale.conf'
 palette.atomic(H/rel,'# HYPR-WIN8 GENERATED LOCALE\nLANG='+locale+'\nLC_MESSAGES='+locale+'\nLANGUAGE='+code+'\n');palette.record(H,[rel,'.config/hypr-win8/theme.json'])
 lock=H/'.config/hypr/win8/hyprlock.conf'
 if lock.exists():
  import re
  text=lock.read_text();text=re.sub(r'(?m)^    placeholder_text = .*$', '    placeholder_text = '+('Пароль' if code=='ru' else 'Password'),text);text=re.sub(r'(?m)^    fail_text = .*$', '    fail_text = '+('Ошибка аутентификации' if code=='ru' else 'Authentication failed'),text)
  palette.atomic(lock,text);palette.record(H,['.config/hypr/win8/hyprlock.conf'])
 if H==pathlib.Path.home():
  values=['LANG='+locale,'LC_MESSAGES='+locale,'LANGUAGE='+code]
  call(['systemctl','--user','set-environment']+values)
  call(['dbus-update-activation-environment']+values)
  if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):call(['hyprctl','eval','hl.env("LANG",'+json.dumps(locale)+');hl.env("LC_MESSAGES",'+json.dumps(locale)+');hl.env("LANGUAGE",'+json.dumps(code)+')'])
def tile_edit(identifier,x,y,w,h,group):
 import fcntl
 x,y,w,h=map(int,(x,y,w,h))
 if (w,h) not in ((1,1),(2,1),(1,2),(2,2)) or not 0<=x<=4-w or not 0<=y<=127:raise ValueError('Invalid tile geometry')
 path=H/'.config/hypr-win8/tiles.json'
 with open(path.parent/'pins.lock','w') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX);tiles=json.loads(path.read_text());tile=next(t for t in tiles if t.get('id')==identifier)
  if group not in {t['group'] for t in tiles}:raise ValueError('Unknown tile group')
  old_x,old_y=tile['x'],tile['y'];tile.update(x=x,y=y,w=w,h=h,group=group)
  def cells(t):return {(a,b) for a in range(t['x'],t['x']+t['w']) for b in range(t['y'],t['y']+t['h'])}
  occupied=cells(tile)
  for other in tiles:
   if other is tile or other['group']!=group:continue
   if occupied & cells(other):
    candidates=[(a,b) for b in range(128) for a in range(5-other['w'])]
    candidates.sort(key=lambda p:(abs(p[0]-old_x)+abs(p[1]-old_y),p[1],p[0]))
    for a,b in candidates:
     trial=dict(other,x=a,y=b)
     if not occupied & cells(trial):other.update(x=a,y=b);break
    else:raise ValueError('No space for tile')
   occupied|=cells(other)
  palette.atomic(path,json.dumps(tiles,ensure_ascii=False,indent=2)+'\n');palette.record(H,['.config/hypr-win8/tiles.json'])
def pin(target,identifier):
 import fcntl
 if target not in ('start','taskbar'):raise ValueError('Invalid pin target')
 app=desktop_app(identifier);identifier=app.get_id();folder=H/'.config/hypr-win8'
 def canonical(value):
  try:return desktop_app(value).get_id()
  except (TypeError,RuntimeError):return value
 with open(folder/'pins.lock','w') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX)
  path=folder/('tiles.json' if target=='start' else 'pins.json')
  data=json.loads(path.read_text())
  if target=='taskbar':
   existing=data.get('taskbar',[])
   if any(canonical(i)==identifier for i in existing):data['taskbar']=[i for i in existing if canonical(i)!=identifier]
   else:data['taskbar']=existing+[identifier]
  else:
   if any(t.get('desktop') and canonical(t['desktop'])==identifier for t in data):data=[t for t in data if not (t.get('desktop') and canonical(t['desktop'])==identifier)]
   else:
    occupied={(x,y) for t in data if t['group']=='Pinned' for x in range(t['x'],t['x']+t['w']) for y in range(t['y'],t['y']+t['h'])}
    slot=next(n for n in range(len(occupied)+1) if (n%4,n//4) not in occupied)
    data.append({'id':'app-'+identifier,'name':app.get_display_name(),'desktop':identifier,'icon':app.get_string('Icon') or 'application-x-executable','w':1,'h':1,'color':'#0078d4','x':slot%4,'y':slot//4,'group':'Pinned'})
  temp=path.with_suffix('.tmp');temp.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');temp.replace(path)
def displays():
 print(call(['hyprctl','monitors','-j'],capture_output=True,text=True).stdout)
def scale(name,value):
 if value not in ('1','1.25','1.5','2'):raise ValueError('Invalid scale')
 monitors=json.loads(call(['hyprctl','monitors','-j'],capture_output=True,text=True).stdout)
 m=next(m for m in monitors if m['name']==name)
 # Retain mode and position; only change requested monitor scale in live session.
 call(['hyprctl','eval','hl.monitor({output='+json.dumps(name)+',mode='+json.dumps(str(m['width'])+'x'+str(m['height'])+'@'+str(m['refreshRate']))+',position='+json.dumps(str(m['x'])+'x'+str(m['y']))+',scale='+value+'})'])
def lock_media():
 result=subprocess.run(['playerctl','metadata','--format','{{artist}} — {{title}}'],capture_output=True,text=True,timeout=2)
 print(result.stdout.strip()[:140] if result.returncode==0 else '')
def lock_status():
 names=[]
 try:
  from gi.repository import Gio,GLib
  bus=Gio.bus_get_sync(Gio.BusType.SYSTEM,None)
  def prop(path,interface,key):return bus.call_sync('org.freedesktop.NetworkManager',path,'org.freedesktop.DBus.Properties','Get',GLib.Variant('(ss)',(interface,key)),None,Gio.DBusCallFlags.NONE,500,None).unpack()[0]
  active=prop('/org/freedesktop/NetworkManager','org.freedesktop.NetworkManager','ActiveConnections')
  names=[prop(p,'org.freedesktop.NetworkManager.Connection.Active','Id') for p in active]
 except Exception:pass
 for p in pathlib.Path('/sys/class/power_supply').glob('*'):
  try:
   if (p/'type').read_text().strip()=='Battery':names.append((p/'capacity').read_text().strip()+'% '+(p/'status').read_text().strip())
  except OSError:pass
 print(' · '.join(names))
def power(action):
 if action=='lock':call(['hyprlock','-c',str(H/'.config/hypr/win8/hyprlock.conf')])
 elif action=='sleep':call(['systemctl','suspend'])
 elif action=='restart':call(['systemctl','reboot'])
 elif action=='shutdown':call(['systemctl','poweroff'])
 elif action=='logout':call(['hyprctl','dispatch','exit'])
 else:raise ValueError('Unknown power action')
if __name__=='__main__':
 try:
  action=sys.argv[1];args=sys.argv[2:]
  appearance_lock=None
  if action in ('theme','custom-color','language','wallpaper','theme-option'):
   import fcntl
   appearance_lock=open(H/'.config/hypr-win8/appearance.lock','w');fcntl.flock(appearance_lock,fcntl.LOCK_EX)
  {'metrics':metrics,'apps-watch':apps_watch,'launch':launch,'inspect-entry':inspect_entry,'clipboard-list':clipboard_list,'clipboard-copy':clipboard_copy,'theme':theme,'custom-color':custom_color,'language':language,'tile-edit':tile_edit,'wallpaper':wallpaper,'theme-option':theme_option,'pin':pin,'displays':displays,'scale':scale,'power':power,'lock-status':lock_status,'lock-media':lock_media}[action](*args)
 except Exception as e:
  print(str(e),file=sys.stderr);notify(str(e));sys.exit(1)
