#!/usr/bin/env python3
import os,sys,json,time,pathlib,subprocess,shutil,shlex
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
def theme(mode=None,accent=None,wallpaper=None):
 p=H/'.config/hypr-win8/theme.json';t=json.loads(p.read_text())
 if mode:t['mode']=('light' if t.get('mode')=='dark' else 'dark') if mode=='toggle' else mode
 if accent:t['accent']=accent
 if wallpaper:t['wallpaper']=wallpaper
 tmp=p.with_suffix('.tmp');tmp.write_text(json.dumps(t,indent=2));tmp.replace(p)
 if accent and os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
  import re
  if re.fullmatch(r'#[0-9a-fA-F]{6}',accent):call(['hyprctl','eval','hl.config({general={col={active_border="rgba('+accent[1:]+'ff)"}}})'])
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
  {'metrics':metrics,'apps-watch':apps_watch,'launch':launch,'inspect-entry':inspect_entry,'clipboard-list':clipboard_list,'clipboard-copy':clipboard_copy,'theme':theme,'displays':displays,'scale':scale,'power':power,'lock-status':lock_status,'lock-media':lock_media}[action](*args)
 except Exception as e:
  print(str(e),file=sys.stderr);notify(str(e));sys.exit(1)
