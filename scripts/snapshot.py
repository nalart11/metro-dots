#!/usr/bin/env python3
import os,sys,json,hashlib,stat,subprocess,datetime,pathlib,shutil
H=pathlib.Path.home(); ROOT=H/'.local/share/hypr-win8-backups'
CONFIGS='hypr waybar rofi quickshell ags kitty foot alacritty dunst mako swaync wlogout hyprpaper swww gtk-3.0 gtk-4.0 Kvantum fish systemd/user illogical-impulse end4-pC matugen qt5ct qt6ct fontconfig xdg-desktop-portal hypr-win8 environment.d'.split()
PATHS=['.config/'+s for s in CONFIGS]+['.local/share/'+s for s in ['themes','icons','fonts','applications']]+['.local/bin','.zshrc','.bashrc','.profile','.xprofile']
def run(args,**kw):return subprocess.run(args,check=True,**kw)
def digest(p):
 h=hashlib.sha256()
 with open(p,'rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
def inventory(base,roots):
 out={}
 def walk(p):
  s=p.lstat(); r=str(p.relative_to(base)); item={'mode':stat.S_IMODE(s.st_mode),'uid':s.st_uid,'gid':s.st_gid}
  if p.is_symlink():item.update(type='link',target=os.readlink(p))
  elif p.is_dir():item['type']='dir'
  elif p.is_file():item.update(type='file',sha256=digest(p),size=s.st_size)
  else:raise RuntimeError('Unsupported special file: '+str(p))
  out[r]=item
  if item['type']=='dir':
   for c in sorted(p.iterdir()):walk(c)
 for r in roots:walk(base/r)
 return out
def roots():
 found=[p for p in PATHS if os.path.lexists(H/p)]
 # Save home symlink targets separately, preserving links themselves.
 for r in list(found):
  for p in [H/r]+list((H/r).rglob('*') if (H/r).is_dir() and not (H/r).is_symlink() else []):
   if p.is_symlink():
    t=p.resolve()
    if t.is_relative_to(H) and t.exists():found.append(str(t.relative_to(H)))
 found=sorted(set(found),key=lambda p:(len(pathlib.Path(p).parts),p))
 minimal=[]
 for p in found:
  if not any(p==q or p.startswith(q+'/') for q in minimal):minimal.append(p)
 return minimal
def verify(s,original=False):
 meta=json.loads((s/'inventory.json').read_text()); paths=json.loads((s/'paths.json').read_text())['saved']
 actual=inventory(s/'backup',paths)
 if {r:{k:v for k,v in x.items() if k not in ('uid','gid')} for r,x in actual.items()}!={r:{k:v for k,v in x.items() if k not in ('uid','gid')} for r,x in meta.items()}:raise RuntimeError('Backup content/permissions/symlinks mismatch')
 ownership={r:{'original':[v['uid'],v['gid']],'copy':[actual[r]['uid'],actual[r]['gid']]} for r,v in meta.items() if [v['uid'],v['gid']]!=[actual[r]['uid'],actual[r]['gid']]}
 (s/'ownership-differences.json').write_text(json.dumps(ownership,indent=2))
 if original and inventory(H,paths)!=meta:raise RuntimeError('Original changed during backup; abort')
 run(['sha256sum','--check','--quiet','checksums.sha256'],cwd=s)
 print('VERIFIED',s, 'entries',len(meta),flush=True)
def snapshot(kind='install'):
 ROOT.mkdir(parents=True,exist_ok=True,mode=0o700)
 s=ROOT/datetime.datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
 if s.exists():s=ROOT/datetime.datetime.now().strftime('%Y-%m-%d_%H-%M-%S_%f')
 s.mkdir(mode=0o700)
 (s/'backup').mkdir(); rs=roots(); original=inventory(H,rs)
 for r in rs:
  dst=s/'backup'/r;dst.parent.mkdir(parents=True,exist_ok=True)
  run(['cp','-a','--',str(H/r),str(dst)])
 (s/'inventory.json').write_text(json.dumps(original,ensure_ascii=False,indent=2))
 (s/'paths.json').write_text(json.dumps({'saved':rs,'absent':[p for p in PATHS if not os.path.lexists(H/p)],'home':str(H),'kind':kind,'locale_env':{k:os.environ.get(k,'') for k in ('LANG','LC_MESSAGES','LANGUAGE')}},indent=2))
 (s/'manifest.txt').write_text('Snapshot type: '+kind+'\nHome: '+str(H)+'\n\nSaved paths:\n'+'\n'.join(rs)+'\n\nAll saved entries:\n'+'\n'.join(sorted(original))+'\n')
 sums=''
 for r,v in sorted(original.items()):
  if v['type']=='file':
   name='backup/'+r
   if '\n' in name or '\\' in name:name='\\'+v['sha256']+'  '+name.replace('\\','\\\\').replace('\n','\\n')
   else:name=v['sha256']+'  '+name
   sums+=name+'\n'
 (s/'checksums.sha256').write_text(sums)
 for file,args in [('packages.txt',['pacman','-Qqe']),('packages-native.txt',['pacman','-Qqen']),('packages-aur.txt',['pacman','-Qqm'])]:
  with open(s/file,'w') as f:run(args,stdout=f)
 for f in ['snapshot.py','restore.sh']:shutil.copy2(pathlib.Path(__file__).parent/f,s/f)
 (s/'README.txt').write_text('Private snapshot. cp -a; symlinks are preserved.\nVerify: python3 snapshot.py verify '+str(s)+'\nRestore: bash '+str(s/'restore.sh')+'\nNo graphical session required. Python 3 and coreutils required.\nRollback first makes another verified snapshot. Added files are retained; managed new files are quarantined only if unchanged.\n')
 for f in ['/tmp/hypr-win8-old-binds.json','/tmp/hypr-win8-monitors.json']:
  if pathlib.Path(f).exists():shutil.copy2(f,s/pathlib.Path(f).name)
 verify(s,True); (s/'VERIFIED').write_text(datetime.datetime.now().isoformat());print('SNAPSHOT='+str(s),flush=True);return s
def known_managed():
 out={}
 for s in ROOT.iterdir():
  if (s/'VERIFIED').exists() and (s/'installed.json').exists():
   for r,h in json.loads((s/'installed.json').read_text()).items():out.setdefault(r,set()).add(h)
  if (s/'VERIFIED').exists() and (s/'runtime-managed.json').exists():
   for r,hashes in json.loads((s/'runtime-managed.json').read_text()).items():out.setdefault(r,set()).update(hashes)
 return out
def check_restored(s,live=False):
 info=json.loads((s/'paths.json').read_text());meta=json.loads((s/'inventory.json').read_text())
 actual=inventory(H,info['saved']);font_cache=[];generated=[];changed=[]
 old_main=s/'backup/.config/hypr/hyprland.lua'
 old_ui=live and old_main.is_file() and 'hyprland.shellOverrides.main' in old_main.read_text()
 runtime_colors={'.config/gtk-3.0/gtk.css','.config/gtk-4.0/gtk.css','.config/hypr/hyprland/colors.lua','.config/hypr/hyprlock/colors.conf'}
 def font_uuid(path):
  try:
   import uuid
   text=path.read_text().strip();return len(text)==36 and str(uuid.UUID(text))==text.lower()
  except (ValueError,OSError):return False
 for r,v in meta.items():
  got=actual.get(r)
  # Fontconfig removes or regenerates deprecated .uuid cache markers on rescan.
  if v['type']=='file' and r.startswith('.local/share/fonts/') and pathlib.Path(r).name=='.uuid':
   if got is None or (got.get('type')=='file' and got.get('mode')==v['mode'] and font_uuid(H/r)):
    if got is None or got.get('sha256')!=v['sha256']:font_cache.append(r)
    continue
  if old_ui and got and got.get('type')=='file' and got.get('mode')==v['mode']:
   if r in runtime_colors:
    if got.get('sha256')!=v['sha256']:generated.append(r)
    continue
   if r=='.config/end4-pC/config.json':
    before=json.loads((s/'backup'/r).read_text());after=json.loads((H/r).read_text())
    before.get('osk',{}).pop('layout',None);after.get('osk',{}).pop('layout',None)
    before.get('background',{}).pop('wallpaperPath',None);after.get('background',{}).pop('wallpaperPath',None)
    if before==after:
     if got.get('sha256')!=v['sha256']:generated.append(r)
     continue
  if {k:x for k,x in (got or {}).items() if k not in ('uid','gid')}!={k:x for k,x in v.items() if k not in ('uid','gid')}:changed.append(r)
 if changed:raise RuntimeError('Restoration verification failed: '+', '.join(changed))
 if font_cache:print('Fontconfig cache UUIDs changed (originals preserved in snapshot): '+', '.join(font_cache),flush=True)
 if generated:print('Original shell regenerated theme/preferences: '+', '.join(generated),flush=True)
 return {'font_cache':font_cache,'generated':generated}
def restore(s,dry=False):
 s=s.resolve();verify(s)
 if not (s/'VERIFIED').exists():raise RuntimeError('Snapshot was not fully verified')
 info=json.loads((s/'paths.json').read_text());meta=json.loads((s/'inventory.json').read_text())
 if info['home']!=str(H):raise RuntimeError('Home mismatch')
 print('Restoring snapshot:',s)
 if dry:print('DRY RUN: verify passed; would preserve current state, stop Win8 shell, restore '+str(len(meta))+' entries and reload.');return
 current=snapshot('pre-rollback');q=current/'quarantine';q.mkdir()
 subprocess.run(['systemctl','--user','stop','hypr-win8-display-*.service'],check=False)
 trial=H/'.local/state/hypr-win8/display-trial.json'
 if trial.exists():
  state=json.loads(trial.read_text());state['status']='cancelled';trial.write_text(json.dumps(state))
 subprocess.run(['systemctl','--user','stop','hypr-win8-shell.service','hypr-win8-clipboard-text.service','hypr-win8-clipboard-image.service'],check=False)
 # Added files installed by this transaction are moved aside only if untouched.
 managed=known_managed()
 for r,hashes in managed.items():
  p=H/r
  if r not in meta and p.is_file() and not p.is_symlink() and digest(p) in hashes and r!='.local/bin/hypr-win8-rollback':
   d=q/r;d.parent.mkdir(parents=True,exist_ok=True);p.rename(d)
 for r,v in sorted(meta.items(),key=lambda x:len(pathlib.Path(x[0]).parts)):
  p=H/r;src=s/'backup'/r
  # Do not follow existing target symlinks. Quarantine conflicting entry.
  conflict=os.path.lexists(p) and (p.is_symlink() or (v['type']=='dir')!=p.is_dir())
  if conflict:
   d=q/r;d.parent.mkdir(parents=True,exist_ok=True)
   if os.path.lexists(d):d=d.with_name(d.name+'.collision')
   p.rename(d)
  p.parent.mkdir(parents=True,exist_ok=True)
  if v['type']=='dir':p.mkdir(exist_ok=True)
  else:run(['cp','-a','--remove-destination','--',str(src),str(p)])
 # Restore directory attributes after children.
 for r,v in sorted(meta.items(),key=lambda x:-len(pathlib.Path(x[0]).parts)):
  if v['type']=='dir':
   if (H/r).stat().st_uid==os.getuid():shutil.copystat(s/'backup'/r,H/r,follow_symlinks=False)
   elif stat.S_IMODE((H/r).stat().st_mode)!=v['mode']:raise RuntimeError('Cannot restore permissions of non-owned directory: '+r)
 # Fontconfig can remove deprecated .uuid cache files while fonts are copied.
 # Recopy missing archived files after the complete tree is in place.
 for r,v in meta.items():
  if v['type']=='file' and not os.path.lexists(H/r):run(['cp','-a','--',str(s/'backup'/r),str(H/r)])
 check_restored(s,live=True)
 activate_restored(info,current)
def activate_restored(info,current):
 subprocess.run(['systemctl','--user','daemon-reload'],check=False)
 if H==pathlib.Path.home():
  locale_file=H/'.config/environment.d/60-hypr-win8-locale.conf'
  defaults=info.get('locale_env',{})
  if not defaults:
   for line in pathlib.Path('/etc/locale.conf').read_text().splitlines():
    if line.startswith('LANG='):defaults={'LANG':line.split('=',1)[1].strip('"')}
  if locale_file.exists():defaults.update(dict(line.split('=',1) for line in locale_file.read_text().splitlines() if line.startswith(('LANG=','LC_MESSAGES=','LANGUAGE='))))
  lang=defaults.get('LANG') or 'C.UTF-8';values=['LANG='+lang,'LC_MESSAGES='+(defaults.get('LC_MESSAGES') or lang),'LANGUAGE='+(defaults.get('LANGUAGE') or lang.split('_')[0])]
  subprocess.run(['systemctl','--user','set-environment']+values,check=False)
  if shutil.which('dbus-update-activation-environment'):subprocess.run(['dbus-update-activation-environment']+values,check=False)
  runtime=pathlib.Path(os.environ.get('XDG_RUNTIME_DIR','/run/user/'+str(os.getuid())))
  # Reapply only Kitty color declarations from restored includes, never commands.
  color_lines=[];visited=set()
  def kitty_colors(file):
   if file in visited or not file.is_file():return
   visited.add(file)
   for line in file.read_text().splitlines():
    if line.startswith('include '):
     child=line.split(None,1)[1].strip();child=pathlib.Path(os.path.expandvars(child)).expanduser();kitty_colors(child if child.is_absolute() else file.parent/child)
    elif line.split(' ',1)[0] in ('background','foreground','cursor','cursor_text_color','selection_background','selection_foreground','active_tab_background','active_tab_foreground','inactive_tab_background','inactive_tab_foreground') or line.split(' ',1)[0].removeprefix('color').isdigit():color_lines.append(line)
  kitty_colors(H/'.config/kitty/kitty.conf')
  import tempfile
  with tempfile.NamedTemporaryFile(mode='w',suffix='.conf') as colors:
   colors.write('\n'.join(color_lines)+'\n');colors.flush()
   for sock in runtime.glob('kitty-*'):
    if sock.is_socket():
     try:subprocess.run(['kitty','@','--to','unix:'+str(sock),'set-colors','--all','--configured',colors.name],capture_output=True,timeout=3)
     except subprocess.TimeoutExpired:pass
 if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
  run(['hyprctl','reload'])
  if H==pathlib.Path.home():subprocess.run(['hyprctl','eval',';'.join('hl.env('+json.dumps(v.split('=',1)[0])+','+json.dumps(v.split('=',1)[1])+')' for v in values)],capture_output=True)
  subprocess.run(['pkill','-u',str(os.getuid()),'-x','hypridle'],check=False)
  if 'require("win8.' in (H/'.config/hypr/hyprland.lua').read_text():
   subprocess.run(['systemctl','--user','start','hypr-win8-shell.service','hypr-win8-clipboard-text.service','hypr-win8-clipboard-image.service'],check=False)
   subprocess.Popen(['hypridle','-c',str(H/'.config/hypr/win8/hypridle.conf')],start_new_session=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
  else:
   subprocess.run(['quickshell','-c','end4-pC','--no-duplicate','--daemonize'],check=False)
   subprocess.Popen(['hypridle'],start_new_session=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
   for kind in ['text','image']:
    subprocess.Popen(['wl-paste','--type',kind,'--watch','bash','-c','cliphist store && qs -c end4-pC ipc call cliphistService update'],start_new_session=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 print('Rollback successful. Preserved current state:',current)
if __name__=='__main__':
 action=sys.argv[1]
 if action=='backup':snapshot(sys.argv[2] if len(sys.argv)>2 else 'install')
 elif action=='verify':verify(pathlib.Path(sys.argv[2]))
 elif action=='restore':restore(pathlib.Path(sys.argv[2]),'--dry-run' in sys.argv)
 elif action=='paths':print('\n'.join(roots()))
