#!/usr/bin/env python3
"""Deterministic wallpaper palettes and reversible application styling."""
import colorsys,json,pathlib,re,hashlib,subprocess,os
from PIL import Image
ROLES=('background','surface','surfaceSecondary','accent','foreground','muted','danger','success','onAccent')
START='/* HYPR-WIN8 GENERATED COLORS BEGIN */';END='/* HYPR-WIN8 GENERATED COLORS END */'
def rgb(value):return tuple(int(value[i:i+2],16)/255 for i in (1,3,5))
def hexcolor(values):return '#'+''.join(f'{round(max(0,min(1,v))*255):02x}' for v in values)
def luminance(value):
 v=[c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb(value)];return .2126*v[0]+.7152*v[1]+.0722*v[2]
def contrast(a,b):
 x,y=sorted((luminance(a),luminance(b)));return (y+.05)/(x+.05)
def text_on(color):return max(('#ffffff','#000000'),key=lambda t:contrast(t,color))
def sample(path):
 try:
  im=Image.open(path);im.seek(0);im=im.convert('RGB');im.thumbnail((128,128))
 except (OSError,ValueError):
  import gi
  gi.require_version('GdkPixbuf','2.0')
  from gi.repository import GdkPixbuf
  p=GdkPixbuf.Pixbuf.new_from_file_at_scale(str(path),128,128,True);mode='RGBA' if p.get_has_alpha() else 'RGB'
  im=Image.frombytes(mode,(p.get_width(),p.get_height()),bytes(p.get_pixels()),'raw',mode,p.get_rowstride()).convert('RGB')
 quant=im.quantize(colors=24);pal=quant.getpalette();candidates=[]
 for count,index in quant.getcolors():
  color=tuple(v/255 for v in pal[index*3:index*3+3]);h,l,s=colorsys.rgb_to_hls(*color)
  candidates.append((count*(.15+s)*(.3+min(l,1-l)),h,s,l))
 _,h,s,l=max(candidates);return h,max(.25,min(.78,s)),l

def lock_image(source,destination):
 from PIL import ImageOps
 try:
  with Image.open(source) as original:im=ImageOps.exif_transpose(original).convert('RGB');im.thumbnail((4096,4096));im=im.copy()
 except (OSError,ValueError):
  import gi
  gi.require_version('GdkPixbuf','2.0')
  from gi.repository import GdkPixbuf
  p=GdkPixbuf.Pixbuf.new_from_file_at_scale(str(source),4096,4096,True);mode='RGBA' if p.get_has_alpha() else 'RGB'
  im=Image.frombytes(mode,(p.get_width(),p.get_height()),bytes(p.get_pixels()),'raw',mode,p.get_rowstride()).convert('RGB')
 destination=pathlib.Path(destination);destination.parent.mkdir(parents=True,exist_ok=True);temp=destination.with_name(destination.name+'.hypr-win8-new');im.save(temp,format='PNG');temp.replace(destination)

def from_hue(h,s,accent=None):
 out={}
 for mode in ('dark','light'):
  dark=mode=='dark';bg=hexcolor(colorsys.hls_to_rgb(h,.075 if dark else .955,.18))
  surface=hexcolor(colorsys.hls_to_rgb(h,.115 if dark else .995,.16));secondary=hexcolor(colorsys.hls_to_rgb(h,.18 if dark else .88,.15))
  color=accent or hexcolor(colorsys.hls_to_rgb(h,.57 if dark else .40,s))
  out[mode]={'background':bg,'surface':surface,'surfaceSecondary':secondary,'accent':color,'foreground':'#f6f7fb' if dark else '#151821','muted':'#c0c6d0' if dark else '#3b4655','danger':'#c42b1c','success':'#16865b','onAccent':text_on(color)}
 return out

def prepare(data,path=None):
 data=dict(data);mode=data.get('mode','dark')
 if path is not None and data.get('autoPalette',True):
  h,s,_=sample(path);data['palettes']=from_hue(h,s);data['paletteSource']=str(path)
 elif not data.get('palettes'):
  h,_,s=colorsys.rgb_to_hls(*rgb(data.get('accent','#0078d4')));data['palettes']=from_hue(h,max(.25,s),data.get('accent'))
 colors=dict(data['palettes'][mode]);colors['onAccent']=text_on(colors['accent']);data['palettes'][mode]=colors
 data.update(colors);data.setdefault('autoPalette',True);data.setdefault('language','ru');return data

def custom(data,role,value):
 if role not in ROLES or not re.fullmatch(r'#[0-9a-fA-F]{6}',value):raise ValueError('Use an opaque #RRGGBB color')
 data=prepare(data);p=dict(data['palettes'][data['mode']]);p[role]=value.lower()
 if role in ('background','surface','surfaceSecondary'):
  if min(contrast(p['foreground'],p[k]) for k in ('background','surface','surfaceSecondary'))<4.5:p['foreground']=text_on(value)
  p['muted']=p['foreground']
  for k in ('background','surface','surfaceSecondary'):
   if contrast(p['foreground'],p[k])<4.5:p[k]=value.lower()
 for key in ('foreground','muted'):
  if min(contrast(p[key],p[k]) for k in ('background','surface','surfaceSecondary'))<4.5:raise ValueError('Text contrast must be at least 4.5:1 against every surface')
 p['onAccent']=text_on(p['accent']);data['palettes'][data['mode']]=p;data['autoPalette']=False;return prepare(data)

def css(colors,gtk4=False):
 p=colors
 mapping={'accent_color':p['accent'],'accent_bg_color':p['accent'],'accent_fg_color':p['onAccent'],'window_bg_color':p['background'],'window_fg_color':p['foreground'],'view_bg_color':p['background'],'view_fg_color':p['foreground'],'headerbar_bg_color':p['surface'],'headerbar_fg_color':p['foreground'],'headerbar_backdrop_color':p['surface'],'card_bg_color':p['surface'],'card_fg_color':p['foreground'],'sidebar_bg_color':p['surface'],'sidebar_fg_color':p['foreground'],'secondary_sidebar_bg_color':p['surfaceSecondary'],'secondary_sidebar_fg_color':p['foreground'],'popover_bg_color':p['surfaceSecondary'],'popover_fg_color':p['foreground'],'dialog_bg_color':p['surface'],'dialog_fg_color':p['foreground'],'destructive_bg_color':p['danger'],'destructive_fg_color':text_on(p['danger']),'success_bg_color':p['success'],'success_fg_color':text_on(p['success'])}
 text=START+'\n'+'\n'.join('@define-color '+key+' '+value+';' for key,value in mapping.items())+'\n'
 if gtk4:text+=':root {\n'+'\n'.join('  --'+k.replace('_','-')+': '+v+';' for k,v in mapping.items())+'\n}\n'
 else:text+='selection {background-color:@accent_bg_color;color:@accent_fg_color;}\n'
 return text+END+'\n'
def merge_css(original,colors,gtk4=False):
 original=re.sub(re.escape(START)+r'.*?'+re.escape(END)+r'\s*','',original,flags=re.S)
 return original.rstrip()+'\n\n'+css(colors,gtk4)
def kitty(colors):
 bg=colors['background'];fg=colors['foreground'];dark=luminance(bg)<.5
 standard=['#a0aabd','#ff7682','#8fd39c','#e6c47c','#7bbce9','#c5a0e6','#79d5d3',fg] if dark else ['#33404a','#9e253a','#28693a','#795500','#205b91','#74408c','#12676a','#151821']
 lines=['# HYPR-WIN8 GENERATED COLORS','background '+bg,'foreground '+fg,'cursor '+fg,'cursor_text_color '+bg,'selection_background '+colors['accent'],'selection_foreground '+colors['onAccent'],'active_tab_background '+colors['accent'],'active_tab_foreground '+colors['onAccent'],'inactive_tab_background '+colors['surface'],'inactive_tab_foreground '+fg]
 for i,c in enumerate(standard*2):
  if i==0:c=bg
  elif i==8:c=colors['muted']
  elif contrast(c,bg)<4.5:c=fg
  lines.append('color'+str(i)+' '+c)
 # Preserve custom extended prompt color indices, while making them readable.
 for i in range(232,256):lines.append('color'+str(i)+' '+(bg if i%2==0 else fg))
 return '\n'.join(lines)+'\n'
def outputs(data,home):
 home=pathlib.Path(home);p=prepare(data);out={'.config/hypr-win8/kitty-colors.conf':kitty(p)}
 for version in (3,4):
  rel=f'.config/gtk-{version}.0/gtk.css';file=home/rel;original=file.read_text() if file.exists() else ''
  out[rel]=merge_css(original,p,version==4)
 file=home/'.config/kitty/kitty.conf';text=file.read_text() if file.exists() else ''
 include='include ~/.config/hypr-win8/kitty-colors.conf'
 if include not in text:text=text.rstrip()+'\n\n# Metro palette; other Kitty settings are preserved\n'+include+'\n'
 out['.config/kitty/kitty.conf']=text;return out

def atomic(path,text):
 path=pathlib.Path(path)
 if path.is_symlink() or any(p.is_symlink() for p in path.parents if p!=pathlib.Path.home()):raise ValueError('Refusing to replace a symlink: '+str(path))
 path.parent.mkdir(parents=True,exist_ok=True);tmp=path.with_name(path.name+'.hypr-win8-new');tmp.write_text(text)
 if path.exists():os.chmod(tmp,path.stat().st_mode & 0o777)
 tmp.replace(path)
def record(home,paths):
 marker=home/'.local/state/hypr-win8/last-install-snapshot'
 if not marker.exists():return
 snap=pathlib.Path(marker.read_text().strip())
 if not (snap/'VERIFIED').exists():return
 file=snap/'runtime-managed.json';history=json.loads(file.read_text()) if file.exists() else {}
 for rel in paths:
  file_path=home/rel
  if file_path.is_file():
   value=hashlib.sha256(file_path.read_bytes()).hexdigest();history[rel]=list(set(history.get(rel,[])+[value]))
 atomic(file,json.dumps(history,indent=2)+'\n')
def runtime(data,home):
 if pathlib.Path(home)!=pathlib.Path.home():return
 p=prepare(data)
 if os.environ.get('HYPRLAND_INSTANCE_SIGNATURE'):
  subprocess.run(['hyprctl','eval','hl.config({general={col={active_border="rgba('+p['accent'][1:]+'ff)"}}})'],capture_output=True)
 if pathlib.Path(home)==pathlib.Path.home():
  runtime_dir=pathlib.Path(os.environ.get('XDG_RUNTIME_DIR','/run/user/'+str(os.getuid())))
  for sock in runtime_dir.glob('kitty-*'):
   if sock.is_socket():
    try:subprocess.run(['kitty','@','--to','unix:'+str(sock),'set-colors','--all','--configured',str(pathlib.Path(home)/'.config/hypr-win8/kitty-colors.conf')],capture_output=True,timeout=3)
    except subprocess.TimeoutExpired:pass
def apply(data,home,live=True):
 home=pathlib.Path(home);data=prepare(data);out=outputs(data,home)
 for rel,text in out.items():atomic(home/rel,text)
 atomic(home/'.config/hypr-win8/theme.json',json.dumps(data,ensure_ascii=False,indent=2)+'\n');record(home,list(out)+['.config/hypr-win8/theme.json'])
 if live:runtime(data,home)
 return data
