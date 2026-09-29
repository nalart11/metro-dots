#!/usr/bin/env python3
"""Exercise display leases and persistence without changing real monitors."""
import sys,pathlib,tempfile,json,time,subprocess
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'scripts'))
import hypr_win8_display as d
with tempfile.TemporaryDirectory() as folder:
 d.H=pathlib.Path(folder);commands=[]
 m=dict(name='test-output',width=1920,height=1080,refreshRate=60.,x=0,y=0,scale=1,availableModes=['1920x1080@60.00Hz','1280x720@60.00Hz'])
 def run(args):
  commands.append(args)
  if args[:2]==['hyprctl','monitors']:return json.dumps([m])
  if args[0]=='cvt':return 'Modeline "1280x720_60.00" 74.50  1280 1344 1472 1664  720 723 728 748 -hsync +vsync\n'
  return ''
 d.run=run
 for args in [('test-output',1920,1080,'nan',1),('test-output',10,1080,60,1),('test-output',1280,720,60,'inf'),('test-output',1600,900,60,1)]:
  try:d.test(*args);raise AssertionError('Invalid mode accepted')
  except ValueError:pass
 d.test('test-output',1280,720,60,1);trial=d.lease();assert trial['status']=='pending'
 assert any(c[0]=='systemd-run' for c in commands)
 try:d.test('test-output',1280,720,60,1);raise AssertionError('Concurrent lease accepted')
 except ValueError:pass
 d.finish('wrong-token',True);assert d.lease()['status']=='pending'
 d.finish(trial['token']);assert d.lease()['status']=='reverted';assert '1920x1080@60.0' in commands[-1][-1]
 d.test('test-output',1280,720,60,1,'true');trial=d.lease();assert trial['new']['mode'].startswith('modeline ') and '  ' not in trial['new']['mode']
 d.finish(trial['token'],True);assert d.lease()['status']=='confirmed'
 assert 'modeline ' in (d.H/'.config/hypr-win8/displays.lua').read_text()
 d.test('test-output',1920,1080,60,1);trial=d.lease();trial['deadline']=time.time()-1;d.atomic(d.directory()/'display-trial.json',trial)
 d.watch(trial['token']);assert d.lease()['status']=='reverted'
 def fail(args):
  if args[0]=='systemd-run':raise subprocess.CalledProcessError(1,args)
  return run(args)
 d.run=fail
 try:d.test('test-output',1920,1080,60,1);raise AssertionError('Missing watchdog accepted')
 except subprocess.CalledProcessError:pass
 assert d.lease()['status']=='reverted'
 print('PASS display validation, watchdog required before apply, concurrent trial refusal, confirmation, CVT persistence and timeout rollback')
