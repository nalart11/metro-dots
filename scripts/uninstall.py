#!/usr/bin/env python3
import pathlib,json,subprocess,os
import snapshot as e
import hypr_win8_palette as palette
import re
H=pathlib.Path.home();marker=H/'.config/hypr-win8/installed'
if not marker.exists():raise SystemExit('Win8 integration is not installed')
s=next(p for p in sorted(e.ROOT.iterdir(),reverse=True) if (p/'VERIFIED').exists() and not (p/'backup/.config/hypr-win8/installed').exists() and json.loads((p/'paths.json').read_text())['kind'] in ('original','install'));e.verify(s);current=e.snapshot('pre-uninstall');q=current/'quarantine';q.mkdir()
subprocess.run(['systemctl','--user','stop','hypr-win8-shell.service','hypr-win8-clipboard-text.service','hypr-win8-clipboard-image.service'],check=False)
# Restore only the main entrypoint; preserve other current personal settings.
r='.config/hypr/hyprland.lua';src=s/'backup'/r
if src.is_file():e.run(['cp','-a','--remove-destination',str(src),str(H/r)])
managed=e.known_managed()
for version in (3,4):
 rel=f'.config/gtk-{version}.0/gtk.css';p=H/rel
 if p.is_file() and e.digest(p) in managed.get(rel,set()):
  text=re.sub(re.escape(palette.START)+r'.*?'+re.escape(palette.END)+r'\s*','',p.read_text(),flags=re.S);palette.atomic(p,text)
kitty=H/'.config/kitty/kitty.conf'
if kitty.is_file():
 text=kitty.read_text();text=text.replace('# Metro palette; other Kitty settings are preserved\n','').replace('include ~/.config/hypr-win8/kitty-colors.conf\n','');palette.atomic(kitty,text)
for r,hashes in managed.items():
 p=H/r
 if r.startswith('.config/hypr/win8/') or r.startswith('.config/quickshell/win8/') or r.startswith('.config/hypr-win8/') or r.startswith('.config/systemd/user/hypr-win8') or (r=='.local/bin/hypr_win8_palette.py') or (r.startswith('.local/bin/hypr-win8') and r!='.local/bin/hypr-win8-rollback'):
  if p.is_file() and not p.is_symlink() and e.digest(p) in hashes:
   dst=q/r;dst.parent.mkdir(parents=True,exist_ok=True);p.rename(dst)
subprocess.run(['systemctl','--user','daemon-reload'],check=False)
if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
 e.run(['hyprctl','reload']);subprocess.run(['pkill','-u',str(os.getuid()),'-x','hypridle'],check=False);subprocess.Popen(['hypridle'],start_new_session=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);subprocess.run(['quickshell','-c','end4-pC','--no-duplicate','--daemonize'],check=False)
if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
 for kind in ['text','image']:
  subprocess.Popen(['wl-paste','--type',kind,'--watch','bash','-c','cliphist store && qs -c end4-pC ipc call cliphistService update'],start_new_session=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
print('Win8 disabled. Backups and project retained. Removed files quarantined in',q)
