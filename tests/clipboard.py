#!/usr/bin/env python3
"""Image thumbnails retain data, obey private modes and degrade to text safely."""
import sys,pathlib,tempfile,subprocess,contextlib,io,json,urllib.parse
from PIL import Image
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'scripts'));import backend as b
with tempfile.TemporaryDirectory() as directory:
 b.H=pathlib.Path(directory);image=io.BytesIO();Image.new('RGB',(1000,500),'blue').save(image,format='PNG');data=image.getvalue()
 def call(args,**kw):
  if args==['cliphist','list']:return subprocess.CompletedProcess(args,0,'1\t[[ binary data 2000 B png 1000x500 ]]\n2\tplain text\n3\t[[ binary data 3 B png ]]\n')
  if args==['cliphist','decode']:return subprocess.CompletedProcess(args,0,data if kw['input']==b'1' else b'bad')
  raise AssertionError(args)
 b.call=call;output=io.StringIO()
 with contextlib.redirect_stdout(output):b.clipboard_list()
 entries=json.loads(output.getvalue());assert len(entries)==3
 thumb=pathlib.Path(urllib.parse.unquote(urllib.parse.urlparse(entries[0]['image']).path))
 assert thumb.stat().st_mode&0o777==0o600 and thumb.parent.stat().st_mode&0o777==0o700
 with Image.open(thumb) as preview:assert preview.width<=640 and preview.height<=256
 assert entries[1]['image'] is None and entries[2]['image'] is None
 thumb.unlink();target=b.H/'unrelated';target.write_bytes(b'do not modify');thumb.symlink_to(target)
 with contextlib.redirect_stdout(io.StringIO()):b.clipboard_list()
 assert target.read_bytes()==b'do not modify'
 print('PASS clipboard thumbnails, private permissions, invalid image fallback and symlink protection')
