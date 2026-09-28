#!/usr/bin/env python3
import pathlib,json,subprocess,os
import snapshot as e
H=pathlib.Path.home();marker=H/'.config/hypr-win8/installed'
if not marker.exists():raise SystemExit('Win8 integration is not installed')
s=next(p for p in sorted(e.ROOT.iterdir(),reverse=True) if (p/'VERIFIED').exists() and not (p/'backup/.config/hypr-win8/installed').exists() and json.loads((p/'paths.json').read_text())['kind'] in ('original','install'));e.verify(s);current=e.snapshot('pre-uninstall');q=current/'quarantine';q.mkdir()
subprocess.run(['systemctl','--user','stop','hypr-win8-shell.service','hypr-win8-clipboard-text.service','hypr-win8-clipboard-image.service'],check=False)
# Restore only the main entrypoint; preserve other current personal settings.
r='.config/hypr/hyprland.lua';src=s/'backup'/r
if src.is_file():e.run(['cp','-a','--remove-destination',str(src),str(H/r)])
for r,hashes in e.known_managed().items():
 p=H/r
 if r.startswith('.config/hypr/win8/') or r.startswith('.config/quickshell/win8/') or r.startswith('.config/hypr-win8/') or r.startswith('.config/systemd/user/hypr-win8') or (r.startswith('.local/bin/hypr-win8') and r!='.local/bin/hypr-win8-rollback'):
  if p.is_file() and not p.is_symlink() and e.digest(p) in hashes:
   dst=q/r;dst.parent.mkdir(parents=True,exist_ok=True);p.rename(dst)
subprocess.run(['systemctl','--user','daemon-reload'],check=False)
if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
 e.run(['hyprctl','reload']);subprocess.run(['pkill','-u',str(os.getuid()),'-x','hypridle'],check=False);subprocess.Popen(['hypridle'],start_new_session=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);subprocess.run(['quickshell','-c','end4-pC','--no-duplicate','--daemonize'],check=False)
if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
 for kind in ['text','image']:
  subprocess.Popen(['wl-paste','--type',kind,'--watch','bash','-c','cliphist store && qs -c end4-pC ipc call cliphistService update'],start_new_session=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
print('Win8 disabled. Backups and project retained. Removed files quarantined in',q)
