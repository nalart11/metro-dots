#!/usr/bin/env python3
import os,sys,json,hashlib,stat,subprocess,datetime,pathlib,shutil
H=pathlib.Path.home(); ROOT=H/'.local/share/hypr-win8-backups'
CONFIGS='hypr waybar rofi quickshell ags kitty foot alacritty dunst mako swaync wlogout hyprpaper swww gtk-3.0 gtk-4.0 Kvantum fish systemd/user illogical-impulse end4-pC matugen qt5ct qt6ct fontconfig xdg-desktop-portal hypr-win8'.split()
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
 (s/'paths.json').write_text(json.dumps({'saved':rs,'absent':[p for p in PATHS if not os.path.lexists(H/p)],'home':str(H),'kind':kind},indent=2))
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
def restore(s,dry=False):
 s=s.resolve();verify(s)
 if not (s/'VERIFIED').exists():raise RuntimeError('Snapshot was not fully verified')
 info=json.loads((s/'paths.json').read_text());meta=json.loads((s/'inventory.json').read_text())
 if info['home']!=str(H):raise RuntimeError('Home mismatch')
 print('Restoring snapshot:',s)
 if dry:print('DRY RUN: verify passed; would preserve current state, stop Win8 shell, restore '+str(len(meta))+' entries and reload.');return
 current=snapshot('pre-rollback');q=current/'quarantine';q.mkdir()
 subprocess.run(['systemctl','--user','stop','hypr-win8-shell.service','hypr-win8-clipboard-text.service','hypr-win8-clipboard-image.service'],check=False)
 # Added files installed by this transaction are moved aside only if untouched.
 managed=json.loads((s/'installed.json').read_text()) if (s/'installed.json').exists() else {}
 for r,h in managed.items():
  p=H/r
  if r not in meta and p.is_file() and not p.is_symlink() and digest(p)==h and r!='.local/bin/hypr-win8-rollback':
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
  if v['type']=='dir':shutil.copystat(s/'backup'/r,H/r,follow_symlinks=False)
 if inventory(H,info['saved']) != meta:
  # Extras are intentionally retained; compare all original entries.
  actual=inventory(H,info['saved'])
  if any({k:x for k,x in actual.get(r,{}).items() if k not in ('uid','gid')}!={k:x for k,x in v.items() if k not in ('uid','gid')} for r,v in meta.items()):raise RuntimeError('Restoration verification failed')
 subprocess.run(['systemctl','--user','daemon-reload'],check=False)
 if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
  run(['hyprctl','reload'])
  subprocess.run(['pkill','-u',str(os.getuid()),'-x','hypridle'],check=False)
  if (H/'.config/hypr-win8/installed').exists():
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
