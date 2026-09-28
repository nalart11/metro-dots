#!/usr/bin/env python3
import os,sys,pathlib,shutil,subprocess,datetime,json,hashlib,argparse,time,re
import snapshot as snapshots
import hypr_win8_palette as palette
H=pathlib.Path.home();R=pathlib.Path(__file__).resolve().parent.parent
DEPENDENCIES={'systemctl':'systemd','systemd-run':'systemd','quickshell':'quickshell','Hyprland':'hyprland','hyprlock':'hyprlock','hypridle':'hypridle','python3':'python','wl-copy':'wl-clipboard','wl-paste':'wl-clipboard','cliphist':'cliphist','grim':'grim','slurp':'slurp','wpctl':'wireplumber','nmcli':'networkmanager','notify-send':'libnotify','kitty':'kitty','hyprsunset':'hyprsunset'}
SCRIPTS={'hypr-win8':'hypr-win8','backend.py':'hypr-win8-backend','hypr_win8_palette.py':'hypr_win8_palette.py','screenshot':'hypr-win8-screenshot','shell-start':'hypr-win8-shell-start','session-start':'hypr-win8-session-start'}
UNITS=['hypr-win8-shell.service','hypr-win8-clipboard-text.service','hypr-win8-clipboard-image.service']
def run(args,**kw):return subprocess.run(args,check=True,**kw)
def planned():
 out=['.config/hypr/hyprland.lua','.config/gtk-3.0/gtk.css','.config/gtk-4.0/gtk.css','.config/kitty/kitty.conf','.config/hypr-win8/kitty-colors.conf','.config/hypr-win8/lock-wallpaper.png','.config/environment.d/60-hypr-win8-locale.conf']
 for folder in ['config/hypr/win8','config/quickshell/win8','config/systemd/user']:
  for p in sorted((R/folder).rglob('*')):
   if p.is_file():out.append('.'+str(p.relative_to(R)))
 out+=['.local/share/applications/hypr-win8-settings.desktop','.config/hypr-win8/pins.json']
 out+=['.local/bin/'+n for n in SCRIPTS.values()]+['.local/bin/hypr-win8-rollback','.config/hypr-win8/installed','.config/hypr-win8/theme.json','.config/hypr-win8/tiles.json']
 return out
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--dry-run',action='store_true');parser.add_argument('--no-packages',action='store_true');parser.add_argument('--restore-on-error',action='store_true');parser.add_argument('--kind',default='install',choices=['install','update']);a=parser.parse_args()
 missing=sorted(set(pkg for cmd,pkg in DEPENDENCIES.items() if not shutil.which(cmd)))
 if a.dry_run:
  print('PRECHECK / DRY RUN\nBackup paths:\n'+'\n'.join(snapshots.roots()))
  print('\nManaged paths:\n'+'\n'.join(planned()));print('\nMissing packages:',', '.join(missing) or 'none');print('User services:',', '.join(UNITS));print('Preserved: custom monitors, NVIDIA environment, input, existing window/workspace binds.');return
 state=H/'.local/state/hypr-win8';state.mkdir(parents=True,exist_ok=True);log=open(state/'install.log','a',buffering=1)
 def phase(name):print(name,flush=True);log.write(datetime.datetime.now().isoformat()+' '+name+'\n')
 phase('PRECHECK')
 if not (H/'.config/hypr/hyprland.lua').is_file():raise RuntimeError('Expected Lua Hyprland configuration was not found')
 if not os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):raise RuntimeError('Install needs a running Hyprland session for Wayland validation; rollback works from TTY.')
 for rel in planned():
  p=H/rel
  for parent in [p]+list(p.parents):
   if parent==H:break
   if parent.is_symlink():raise RuntimeError('Managed path crosses symlink; refusing install: '+str(parent))
 # Package installation is a single explicit operation within INSTALL after validation.
 for cmd in ['quickshell','Hyprland','hyprlock']:
  if not shutil.which(cmd):raise RuntimeError('Validation prerequisite missing. Install explicitly before this transaction: sudo pacman -S --needed '+DEPENDENCIES[cmd])
 phase('BACKUP');s=snapshots.snapshot(a.kind)
 phase('VERIFY_BACKUP');snapshots.verify(s)
 official=[]
 if missing:
  if a.no_packages:raise RuntimeError('Missing dependencies: '+', '.join(missing))
  official=[];aur=[]
  for p in missing:
   test=subprocess.run(['pacman','-Si',p],capture_output=True)
   (official if test.returncode==0 else aur).append(p)
  if aur:raise RuntimeError('AUR dependency needed: '+', '.join(aur)+'. Existing helper: '+str(shutil.which('paru') or shutil.which('yay'))+'. Install explicitly and retry.')
 phase('GENERATE_CONFIG')
 stage=H/'.cache/hypr-win8-build'/datetime.datetime.now().strftime('%Y-%m-%d_%H-%M-%S_%f');stage.mkdir(parents=True)
 # Keep the full include chain in staging for validation. Install only managed files.
 run(['cp','-a',str(H/'.config/hypr'),str(stage/'hypr')])
 run(['cp','-a',str(R/'config/hypr/win8'),str(stage/'hypr/win8')]) if not (stage/'hypr/win8').exists() else run(['cp','-a',str(R/'config/hypr/win8')+'/.',str(stage/'hypr/win8')])
 original=(H/'.config/hypr/hyprland.lua').read_text()
 if 'require("win8.appearance")' not in original:
  original=original.replace('require("hyprland.execs")','require("win8.autostart")').replace('require("hyprland.shellOverrides.main")','require("win8.appearance")\nrequire("win8.binds")')
  if 'require("win8.appearance")' not in original:raise RuntimeError('Unknown main config structure; refusing automatic migration')
 (stage/'hypr/hyprland.lua').write_text(original)
 run(['cp','-a',str(R/'config/quickshell/win8'),str(stage/'win8')]);(stage/'data').mkdir()
 for name in ['theme.json','tiles.json','pins.json']:
  src=H/'.config/hypr-win8'/name
  shutil.copy2(src if src.exists() else R/'defaults'/name,stage/'data'/name)
 # Repair only the generated stale default tile; retain other user tile edits.
 tile_file=stage/'data/tiles.json';tile_data=json.loads(tile_file.read_text())
 for tile in tile_data:
  if 'id' not in tile:tile['id']='tile-'+hashlib.sha256((tile.get('name','')+'|'+tile.get('desktop','')+'|'+tile.get('live','')).encode()).hexdigest()[:14]
  if tile.get('name')=='Code' and tile.get('desktop')=='dev.zed.Zed' and not (H/'.local/zed.app/bin/zed').exists() and shutil.which('codium'):
   tile.update(desktop='codium',icon='vscodium');log.write('Migrated stale Zed default tile to installed VSCodium\n')
 tile_file.write_text(json.dumps(tile_data,ensure_ascii=False,indent=2)+'\n')
 theme_path=stage/'data/theme.json';theme=json.loads(theme_path.read_text());wall=theme.get('wallpaper','metro-blue.svg');wall=pathlib.Path(wall) if wall.startswith('/') else R/'assets/wallpapers'/wall
 theme=palette.prepare(theme,wall);theme_path.write_text(json.dumps(theme,ensure_ascii=False,indent=2)+'\n')
 generated={}
 for rel,text in palette.outputs(theme,H).items():
  dest=stage/'generated'/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(text)
  if (H/rel).exists():shutil.copymode(H/rel,dest)
  generated[rel]=dest
 lock_image=stage/'generated/lock-wallpaper.png';current_lock=H/'.config/hypr-win8/lock-wallpaper.png'
 if current_lock.exists():shutil.copy2(current_lock,lock_image)
 else:palette.lock_image(theme.get('lockWallpaper') or wall,lock_image)
 generated['.config/hypr-win8/lock-wallpaper.png']=lock_image
 lang=theme.get('language','ru');locale={'ru':'ru_RU.UTF-8','en':'en_US.UTF-8'}[lang];locale_file=stage/'generated/locale.conf';locale_file.write_text('# HYPR-WIN8 GENERATED LOCALE\nLANG='+locale+'\nLC_MESSAGES='+locale+'\nLANGUAGE='+lang+'\n');generated['.config/environment.d/60-hypr-win8-locale.conf']=locale_file
 phase('VALIDATE_CONFIG')
 for version in (3,4):
  # Parse the new CSS separately; existing user imports remain byte-for-byte.
  css=stage/('metro-gtk'+str(version)+'.css');css.write_text(palette.css(theme,version==4))
  check="import gi;gi.require_version('Gtk', '"+str(version)+".0');from gi.repository import Gtk;p=Gtk.CssProvider();errors=[];p.connect('parsing-error',lambda provider,section,error:errors.append(str(error)));p.load_from_path("+repr(str(css))+");assert not errors,errors"
  run(['python3','-c',check])
 for p in R.rglob('*.sh'):run(['bash','-n',str(p)])
 for name in ['hypr-win8','screenshot','shell-start','session-start']:run(['bash','-n',str(R/'scripts'/name)])
 for p in (stage/'data').glob('*.json'):json.loads(p.read_text())
 tiles=json.loads((stage/'data/tiles.json').read_text())
 occupied={}
 for t in tiles:
  if (t['w'],t['h']) not in [(1,1),(2,1),(1,2),(2,2)]:raise RuntimeError('Unsupported tile size: '+t['name'])
  for x in range(t['x'],t['x']+t['w']):
   for y in range(t['y'],t['y']+t['h']):
    key=(t['group'],x,y)
    if key in occupied:raise RuntimeError('Overlapping tiles: '+t['name'])
    occupied[key]=t['name']
 import resource
 def no_core():resource.setrlimit(resource.RLIMIT_CORE,(0,0))
 lock=subprocess.run(['hyprlock','-c',str(stage/'hypr/win8/hyprlock.conf'),'--display','hypr-win8-validation-no-server'],capture_output=True,text=True,preexec_fn=no_core,timeout=5)
 (stage/'hyprlock-validation.log').write_text(lock.stdout+lock.stderr)
 if 'Config has errors' in lock.stdout+lock.stderr or "Couldn't connect to a wayland compositor" not in lock.stdout+lock.stderr:raise RuntimeError('Hyprlock parse check failed: '+str(stage/'hyprlock-validation.log'))
 result=run(['Hyprland','--verify-config','-c',str(stage/'hypr/hyprland.lua')],capture_output=True,text=True)
 (stage/'hypr-validation.log').write_text(result.stdout+result.stderr)
 if 'Config parsing result:' not in result.stdout or result.stdout.split('Config parsing result:',1)[1].strip()!='config ok':raise RuntimeError('Hyprland validation failed; see '+str(stage/'hypr-validation.log'))
 env=os.environ.copy();env.update(HYPR_WIN8_VALIDATE='1',HYPR_WIN8_DATA=str(stage/'data'))
 with open(stage/'qml-validation.log','w') as output:
  proc=subprocess.Popen(['quickshell','-p',str(stage/'win8'),'--no-color'],env=env,stdout=output,stderr=output)
  time.sleep(3)
  alive=proc.poll() is None
  if alive:proc.terminate();proc.wait(timeout=5)
 qml=(stage/'qml-validation.log').read_text()
 if not alive or 'Configuration Loaded' not in qml or ' ERROR' in qml or 'ReferenceError' in qml or 'TypeError' in qml:raise RuntimeError('QML validation failed; see '+str(stage/'qml-validation.log'))
 files={'.config/hypr/hyprland.lua':stage/'hypr/hyprland.lua','.local/share/applications/hypr-win8-settings.desktop':R/'config/applications/hypr-win8-settings.desktop'}
 files.update(generated)
 for folder in ['config/hypr/win8','config/quickshell/win8','config/systemd/user']:
  for p in (R/folder).rglob('*'):
   if p.is_file():files['.'+str(p.relative_to(R))]=p
 for src,dst in SCRIPTS.items():files['.local/bin/'+dst]=R/'scripts'/src
 files['.local/bin/hypr-win8-rollback']=R/'rollback.sh'
 for name in ['theme.json','tiles.json','pins.json']:files['.config/hypr-win8/'+name]=stage/'data'/name
 marker=stage/'installed';marker.write_text(str(s)+'\n');files['.config/hypr-win8/installed']=marker
 snapshots.verify(s)
 (s/'installed.json').write_text(json.dumps({rel:snapshots.digest(p) for rel,p in files.items()},indent=2))
 phase('INSTALL')
 try:
  if official:run(['sudo','pacman','-S','--needed']+official)
  for rel,src in files.items():
   dst=H/rel;dst.parent.mkdir(parents=True,exist_ok=True)
   # Copy to sibling first, then atomic replace. Existing dotfile is always in verified snapshot.
   temp=dst.with_name(dst.name+'.hypr-win8-new');run(['cp','-a','--',str(src),str(temp)]);temp.replace(dst)
  run(['systemctl','--user','daemon-reload'])
  for name in ['end4-pC','ii']:subprocess.run(['quickshell','kill','-c',name],check=False,capture_output=True)
  # Stop only old watchers identified by command, not arbitrary wl-paste clients.
  listing=run(['ps','-u',str(os.getuid()),'-o','pid=,args='],capture_output=True,text=True).stdout
  for line in listing.splitlines():
   if 'wl-paste --type ' in line and 'cliphistService update' in line and not 'ps -' in line:
    pid=int(line.split()[0]);os.kill(pid,15)
  (H/'.local/state/hypr-win8/last-install-snapshot').write_text(str(s)+'\n')
  phase('RELOAD');run(['hyprctl','reload'])
  palette.runtime(theme,H)
  run(['python3',str(H/'.local/bin/hypr-win8-backend'),'language',lang])
  run(['systemctl','--user','import-environment','WAYLAND_DISPLAY','HYPRLAND_INSTANCE_SIGNATURE','XDG_CURRENT_DESKTOP','DISPLAY'])
  run(['systemctl','--user','restart']+UNITS)
  # Replace the old idle daemon with the dedicated config, retaining the no-auto-lock policy.
  subprocess.run(['pkill','-u',str(os.getuid()),'-x','hypridle'],check=False)
  subprocess.Popen(['hypridle','-c',str(H/'.config/hypr/win8/hypridle.conf')],stdout=log,stderr=log,start_new_session=True)
  phase('POSTCHECK');time.sleep(3)
  run(['systemctl','--user','is-active']+UNITS)
  errors=run(['hyprctl','configerrors'],capture_output=True,text=True).stdout.strip()
  if errors and errors!='ok':raise RuntimeError('Hyprland config errors: '+errors)
  status=run(['quickshell','-c','win8','ipc','call','metro','status'],capture_output=True,text=True).stdout
  log.write(status+'\n');print(status)
  (H/'.local/state/hypr-win8/last-install-snapshot').write_text(str(s)+'\n')
  phase('COMPLETE');print('Rollback: '+str(H/'.local/bin/hypr-win8-rollback')+' --latest')
 except BaseException as e:
  log.write('FAILED '+str(e)+'\n');print('Install failed after INSTALL:',e,file=sys.stderr)
  if a.restore_on_error:snapshots.restore(s)
  else:
   print('Verified rollback available: bash '+str(s/'restore.sh'),file=sys.stderr)
   if sys.stdin.isatty() and input('Restore automatically now? [y/N] ').lower()=='y':snapshots.restore(s)
  raise
if __name__=='__main__':main()
