#!/usr/bin/env python3
import pathlib,sys,tempfile,subprocess,os,json
R=pathlib.Path(__file__).resolve().parents[1];sys.path.insert(0,str(R/'scripts'));import hypr_win8_palette as palette
base=json.loads((R/'defaults/theme.json').read_text())
for language in ('ru','en'):
 for mode in ('dark','light'):
  data=palette.prepare(dict(base,mode=mode,language=language));text=palette.lock_colors(data)
  assert '$metroAccent = rgba('+data['accent'][1:]+'ff)' in text
  assert '$metroSurface = rgba('+data['surface'][1:]+'ff)' in text
  assert '$metroText = rgba('+data['foreground'][1:]+'ff)' in text
  assert ('Пароль' if language=='ru' else 'Password') in text
with tempfile.TemporaryDirectory(prefix='metro-session-start-') as temporary:
 home=pathlib.Path(temporary);log=home/'calls';bin=home/'bin';bin.mkdir()
 for name,text in {'systemctl':'printf "%s\\n" "$*" >> "$TEST_CALLS"\n','pgrep':'exit 1\n'}.items():
  file=bin/name;file.write_text('#!/bin/sh\n'+text);file.chmod(0o755)
 subprocess.run(['bash',str(R/'scripts/session-start')],env=dict(os.environ,PATH=str(bin)+':'+os.environ['PATH'],TEST_CALLS=str(log)),check=True)
 calls=log.read_text().splitlines();assert calls[1]=='--user start hypr-win8-lock.service';assert 'hypr-win8-shell.service' in calls[2]
 unit=(R/'config/systemd/user/hypr-win8-lock.service').read_text();assert '--grace 0' in unit and 'Restart=on-failure' in unit
 print('PASS dark/light lock field colors, ru/en prompt and startup lock before shell services')
