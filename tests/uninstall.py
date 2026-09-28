#!/usr/bin/env python3
"""Rehearse removal in a disposable home, preserving unrelated application settings."""
import pathlib,tempfile,sys,json,subprocess,runpy,os
R=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(R/'scripts'))
import snapshot as e
import hypr_win8_palette as palette
with tempfile.TemporaryDirectory(prefix='hypr-win8-uninstall-test-') as tmp:
 h=pathlib.Path(tmp);e.H=h;e.ROOT=h/'.local/share/hypr-win8-backups'
 original_home=pathlib.Path.home
 pathlib.Path.home=classmethod(lambda cls:h)
 original_run=subprocess.run
 def stub(args,**kw):
  if args[0]=='systemctl':return subprocess.CompletedProcess(args,0)
  return original_run(args,**kw)
 subprocess.run=stub;signature=os.environ.pop('HYPRLAND_INSTANCE_SIGNATURE',None)
 try:
  for rel,text in {'.config/hypr/hyprland.lua':'require("original")\n','.config/kitty/kitty.conf':'font_size 13\nmap ctrl+t new_tab\n','.config/gtk-3.0/gtk.css':'/* user GTK3 */\n','.config/gtk-4.0/gtk.css':'/* user GTK4 */\n'}.items():
   p=h/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
  s=e.snapshot('original');theme=palette.prepare({'mode':'dark','accent':'#0078d4'})
  for rel,text in palette.outputs(theme,h).items():palette.atomic(h/rel,text)
  extras={'.config/hypr-win8/installed':str(s),'.local/bin/hypr_win8_palette.py':'# owned palette helper\n','.local/bin/hypr-win8-rollback':'# keep emergency command\n'}
  for rel,text in extras.items():palette.atomic(h/rel,text)
  files={rel:e.digest(h/rel) for rel in list(palette.outputs(theme,h))+list(extras)};(s/'installed.json').write_text(json.dumps(files))
  (h/'.config/kitty/kitty.conf').write_text((h/'.config/kitty/kitty.conf').read_text()+'font_family monospace\n')
  runpy.run_path(str(R/'scripts/uninstall.py'),run_name='__main__')
  assert (h/'.config/hypr/hyprland.lua').read_text()=='require("original")\n'
  kitty=(h/'.config/kitty/kitty.conf').read_text();assert 'font_size 13' in kitty and 'font_family monospace' in kitty and 'hypr-win8/kitty-colors.conf' not in kitty
  for version in (3,4):
   css=(h/f'.config/gtk-{version}.0/gtk.css').read_text();assert f'user GTK{version}' in css and palette.START not in css
  assert not (h/'.config/hypr-win8/kitty-colors.conf').exists() and not (h/'.local/bin/hypr_win8_palette.py').exists()
  assert (h/'.local/bin/hypr-win8-rollback').exists() and (s/'VERIFIED').exists()
  assert any((snap/'quarantine/.config/hypr-win8/kitty-colors.conf').exists() for snap in e.ROOT.iterdir())
  print('PASS isolated uninstall detaches generated GTK/Kitty styling, preserves later user fonts/binds, quarantines owned files, keeps backups and emergency recovery')
 finally:
  pathlib.Path.home=original_home;subprocess.run=original_run
  if signature is not None:os.environ['HYPRLAND_INSTANCE_SIGNATURE']=signature
