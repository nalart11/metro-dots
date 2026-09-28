#!/usr/bin/env python3
"""Exercise persistent pins and image validation in a disposable home."""
import importlib.util,json,pathlib,tempfile,urllib.parse,shutil,sys
root=pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'scripts'))
spec=importlib.util.spec_from_file_location('backend',root/'scripts/backend.py');backend=importlib.util.module_from_spec(spec);spec.loader.exec_module(backend)
with tempfile.TemporaryDirectory(prefix='hypr-win8-personalization-') as tmp:
 backend.H=pathlib.Path(tmp);folder=backend.H/'.config/hypr-win8';folder.mkdir(parents=True)
 for name in ['theme.json','tiles.json','pins.json']:shutil.copy2(root/'defaults'/name,folder/name)
 original=json.loads((folder/'tiles.json').read_text())
 backend.pin('start','org.telegram.desktop.desktop');assert len(json.loads((folder/'tiles.json').read_text()))==len(original)-1
 backend.pin('start','org.telegram.desktop');tiles=json.loads((folder/'tiles.json').read_text());assert len(tiles)==len(original)
 assert sum(t.get('desktop') in ('org.telegram.desktop','org.telegram.desktop.desktop') for t in tiles)==1
 backend.pin('taskbar','firefox');assert 'firefox.desktop' not in json.loads((folder/'pins.json').read_text())['taskbar']
 backend.pin('taskbar','firefox.desktop');assert json.loads((folder/'pins.json').read_text())['taskbar'].count('firefox.desktop')==1
 image=backend.H/'обои с пробелом # %.png';shutil.copy2(root/'assets/wallpapers/metro-blue.png',image)
 backend.wallpaper(image.as_uri());assert json.loads((folder/'theme.json').read_text())['wallpaper']==str(image)
 invalid=backend.H/'bad.png';invalid.write_text('not an image');saved=(folder/'theme.json').read_bytes()
 try:backend.wallpaper(str(invalid));raise AssertionError('Invalid image was accepted')
 except ValueError:pass
 assert (folder/'theme.json').read_bytes()==saved
 backend.theme_option('wallpaperFit','fit');assert json.loads((folder/'theme.json').read_text())['wallpaperFit']=='fit'
 print('PASS pin/unpin canonical desktop IDs, persistent taskbar pins, encoded file URL and invalid-image rejection; live files untouched')
