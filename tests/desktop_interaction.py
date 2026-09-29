import subprocess,os,json,time,pathlib,sys
# Opt in: this temporarily focuses and moves its own test window in a live session.
if sys.argv[1:] != ["--live"]:
 print("Usage: python3 tests/desktop_interaction.py --live (requires installed Metro, Hyprland, kitty and ydotool)")
 raise SystemExit(2)
os.environ['QT_QPA_PLATFORM']='wayland'
H=pathlib.Path.home()
qaClass='metro-overview-qa-'+str(os.getpid())
def run(a):return subprocess.check_output(a,text=True)
def ipc(m,*a):return run(['quickshell','-c','win8','ipc','call','metro',m,*a])
def state():return json.loads(ipc('status'))
def keys(*a):subprocess.run(['ydotool','key',*a],check=True,stdout=subprocess.DEVNULL)
def backend(a,*args):subprocess.run(['python3',str(H/'.local/bin/hypr-win8-backend'),a,*map(str,args)],check=True,stdout=subprocess.DEVNULL)
def focus(a):backend('window-focus',a);time.sleep(.3)
def clients():return json.loads(run(['hyprctl','clients','-j']))
def active():return json.loads(run(['hyprctl','activewindow','-j']))['address'].removeprefix('0x')
def wait(test,timeout=4):
 end=time.monotonic()+timeout
 while time.monotonic()<end:
  value=test()
  if value:return value
  time.sleep(.06)
 raise AssertionError('Timed out')
def mouse(x,y):subprocess.run(['ydotool','mousemove','-a',str(round(x/2)),str(round(y/2))],check=True,stdout=subprocess.DEVNULL)
def click(code='0xC0'):subprocess.run(['ydotool','click',code],check=True,stdout=subprocess.DEVNULL)
keyboardLayouts={k['name']:k['active_layout_index'] for k in json.loads(run(['hyprctl','devices','-j']))['keyboards']}
original=active();originalWS=json.loads(run(['hyprctl','activeworkspace','-j']))['id'];qa=None
try:
 ws=max(c['workspace']['id'] for c in clients())+1;backend('workspace-focus',ws)
 qa=subprocess.Popen(['kitty','--class',qaClass,'--title','Metro overview regression','sh','-c','sleep 180'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 client=wait(lambda:next((c for c in clients() if c['class']==qaClass),None));address=client['address'].removeprefix('0x');focus(original)
 keys('56:1','15:1','15:0');wait(lambda:state()['page']=='switcher');time.sleep(.3);s=state();assert s['switchWindows'][0]==original,s
 assert s['switchWindows'][s['selectedWindow']]==address,s
 order=s['switchWindows'];previous=s['selectedWindow'];keys('15:1','15:0');time.sleep(.18);s=state();assert s['switchWindows']==order and s['selectedWindow']==(previous+1)%len(order)
 keys('42:1');time.sleep(.1);keys('15:1','15:0');time.sleep(.1);keys('42:0');time.sleep(.18);s=state();assert s['selectedWindow']==previous,s
 keys('56:0');wait(lambda:state()['page']=='');wait(lambda:active()==address);focus(original);print('PASS MRU forward/reverse, stable cycle and release-to-focus')
 keys('56:1','15:1','15:0');wait(lambda:state()['page']=='switcher');keys('1:1','1:0','56:0');wait(lambda:state()['page']=='');assert active()==original;print('PASS Alt+Tab Escape cancels')
 keys('56:1','15:1','15:0');time.sleep(.06);keys('56:0');wait(lambda:state()['page']=='');wait(lambda:active()==address);focus(original);print('PASS quick Alt+Tab release')
 time.sleep(.4);keys('125:1','15:1','15:0');wait(lambda:state()['page']=='workspaces');keys('125:0');time.sleep(.45);s=state();assert s['page']=='workspaces';assert s['overview'],s
 print('PASS Super+Tab persists after Super release')
 frames=s['overview'];frame=next(f for f in frames if f['workspace']==ws);window=next(w for w in frame['windows'] if w['address']==address);target=next(f for f in frames if f['workspace']>ws);targetWS=target['workspace']
 print('COMPOSITION',[(f['workspace'],round(f['width']),round(f['height']),len(f['windows'])) for f in frames])
 screen=next(m for m in json.loads(run(['hyprctl','monitors','-j'])) if m['name']==s['monitor']);ox,oy=screen['x'],screen['y']
 start=(ox+window['x']+window['width']/2,oy+window['y']+window['height']/2);end=(ox+target['x']+target['width']/2,oy+target['y']+target['height']/2)
 mouse(*start);click('0x40');time.sleep(.12)
 for step in range(1,17):mouse(start[0]+(end[0]-start[0])*step/16,start[1]+(end[1]-start[1])*step/16);time.sleep(.022)
 click('0x80');wait(lambda:next(c for c in clients() if c['address'].removeprefix('0x')==address)['workspace']['id']==targetWS)
 assert state()['page']=='workspaces';print('PASS drag window to new Desktop without closing overview')
 time.sleep(.5);s=state();frame=next(f for f in s['overview'] if f['workspace']==targetWS);window=next(w for w in frame['windows'] if w['address']==address)
 point=(ox+window['x']+window['width']/2,oy+window['y']+window['height']/2);mouse(*point);click('0xC1');time.sleep(.3)
 keys('108:1','108:0','28:1','28:0');wait(lambda:next(c for c in clients() if c['address'].removeprefix('0x')==address)['workspace']['id']==1)
 time.sleep(.4);s=state();assert s['page']=='workspaces';frame=next(f for f in s['overview'] if f['workspace']==1);window=next(w for w in frame['windows'] if w['address']==address);point=(ox+window['x']+window['width']/2,oy+window['y']+window['height']/2)
 print('PASS move menu across monitors')
 mouse(*point);click();wait(lambda:state()['page']=='');wait(lambda:active()==address);print('PASS right-click menu and clickable full-workspace window')
 ipc('toggle','start');time.sleep(.12);assert state()['chromeOpacity']==0;time.sleep(.45);assert state()['chromeOpacity']==1
 ipc('close');time.sleep(.08);s=state();assert s['chromeOpacity']==0 and s['displayPage']=='start';time.sleep(.3);assert state()['displayPage']=='';print('PASS Start chrome appears last and closes first')
finally:
 keys('56:0','125:0','42:0');ipc('close')
 if qa is not None:qa.terminate();qa.wait(timeout=5)
 backend('workspace-focus',originalWS);focus(original)
 for keyboard in json.loads(run(['hyprctl','devices','-j']))['keyboards']:
  index=keyboardLayouts.get(keyboard['name'])
  if index is not None and keyboard['active_layout_index']!=index:subprocess.run(['hyprctl','switchxkblayout',keyboard['name'],str(index)],check=True,stdout=subprocess.DEVNULL)
