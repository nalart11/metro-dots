#!/usr/bin/env python3
"""Exercise app colors, independent wallpapers, locale and collision-safe layouts."""
import importlib.util,json,pathlib,tempfile,sys,shutil,stat
from PIL import Image
R=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(R/'scripts'))
import hypr_win8_palette as palette
spec=importlib.util.spec_from_file_location('backend',R/'scripts/backend.py');b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
with tempfile.TemporaryDirectory(prefix='hypr-win8-palette-test-') as tmp:
 b.H=pathlib.Path(tmp);folder=b.H/'.config/hypr-win8';folder.mkdir(parents=True)
 for name in ('theme.json','tiles.json','pins.json'):shutil.copy2(R/'defaults'/name,folder/name)
 for version in (3,4):
  css=b.H/f'.config/gtk-{version}.0/gtk.css';css.parent.mkdir();css.write_text('/* original user settings */\n@define-color custom #abcdef;\n')
 kitty=b.H/'.config/kitty/kitty.conf';kitty.parent.mkdir();kitty.write_text('font_size 13\nmap ctrl+shift+t new_tab\n');kitty.chmod(0o640)
 walls=[]
 for color in ('#ff7722','#22aaaa'):
  path=b.H/(color[1:]+'.png');Image.new('RGB',(80,60),color).save(path);walls.append(path)
 b.wallpaper(walls[0].as_uri());first=json.loads((folder/'theme.json').read_text())
 b.wallpaper(walls[1].as_uri());second=json.loads((folder/'theme.json').read_text());assert first['accent']!=second['accent']
 for mode,p in second['palettes'].items():
  for fg in ('foreground','muted'):
   for bg in ('background','surface','surfaceSecondary'):assert palette.contrast(p[fg],p[bg])>=4.5,(mode,fg,bg)
  assert palette.contrast(p['onAccent'],p['accent'])>=4.5
  kitty_colors=palette.kitty(p)
  for line in kitty_colors.splitlines():
   if line.startswith('color') and 0<int(line.split()[0][5:])<16:assert palette.contrast(line.split()[1],p['background'])>=4.5,line
 b.custom_color('accent','#decade');b.wallpaper(str(walls[0]));t=json.loads((folder/'theme.json').read_text());assert t['accent']=='#decade' and not t['autoPalette']
 b.custom_color('background','#ffffff');t=json.loads((folder/'theme.json').read_text());assert t['background']=='#ffffff' and palette.contrast(t['foreground'],t['background'])>=4.5
 b.wallpaper(str(walls[1]),'lock');assert json.loads((folder/'theme.json').read_text())['wallpaper']==str(walls[0]);assert Image.open(folder/'lock-wallpaper.png').getpixel((0,0))==(34,170,170)
 for version in (3,4):
  text=(b.H/f'.config/gtk-{version}.0/gtk.css').read_text();assert text.count(palette.START)==1 and 'original user settings' in text and 'custom #abcdef' in text
 assert stat.S_IMODE(kitty.stat().st_mode)==0o640 and kitty.read_text().count('include ~/.config/hypr-win8/kitty-colors.conf')==1
 b.language('en');assert 'LANG=en_US.UTF-8' in (b.H/'.config/environment.d/60-hypr-win8-locale.conf').read_text();b.language('ru')
 tiles=json.loads((folder/'tiles.json').read_text())
 for i,t in enumerate(tiles):t['id']='test-'+str(i)
 (folder/'tiles.json').write_text(json.dumps(tiles));ids={t['id'] for t in tiles}
 for w,h in ((1,1),(2,1),(1,2),(2,2)):
  b.tile_edit('test-0',2,1,w,h,tiles[0]['group']);updated=json.loads((folder/'tiles.json').read_text());assert {t['id'] for t in updated}==ids;occupied=set()
  for t in updated:
   for x in range(t['x'],t['x']+t['w']):
    for y in range(t['y'],t['y']+t['h']):assert (t['group'],x,y) not in occupied;occupied.add((t['group'],x,y))
  t=next(t for t in updated if t['id']=='test-0');assert (t['x'],t['y'],t['w'],t['h'])==(2,1,w,h)
 print('PASS wallpaper-derived dual palettes, WCAG text/ANSI contrast, custom colors, preserved CSS/Kitty settings and modes, separate lock wallpaper, ru/en locale, all four collision-safe tile sizes')
