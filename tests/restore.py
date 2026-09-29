import sys,pathlib,tempfile,os,json,subprocess
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'scripts'));import snapshot as e
h=pathlib.Path(tempfile.mkdtemp(prefix='hypr-win8-restore-test-'));e.H=h;e.ROOT=h/'snapshots';e.PATHS=['.config/hypr','.local/bin','.local/share/fonts'];e.CONFIGS=['hypr']
f=h/'.config/hypr';f.mkdir(parents=True);(f/'original').write_text('original');os.chmod(f/'original',0o640);(f/'link').symlink_to('original')
(f/'hyprland.lua').write_text('require("hyprland.shellOverrides.main")')
b=h/'.local/bin';b.mkdir(parents=True);(b/'tool').write_text('old');os.chmod(b/'tool',0o755)
fonts=h/'.local/share/fonts';fonts.mkdir(parents=True);(fonts/'.uuid').write_text('12345678-1234-1234-1234-123456789012');(fonts/'font.ttf').write_bytes(b'fixture font data')
s=e.snapshot('original');(f/'original').write_text('changed');(f/'extra').write_text('user added');(f/'new').write_text('installed');(s/'installed.json').write_text(json.dumps({'.config/hypr/new':e.digest(f/'new')}))
(f/'new').write_text('installed version two')
update=e.snapshot('update');(update/'installed.json').write_text(json.dumps({'.config/hypr/new':e.digest(f/'new')}))
(f/'runtime').write_text('runtime-generated color data');(update/'runtime-managed.json').write_text(json.dumps({'.config/hypr/runtime':[e.digest(f/'runtime')]}))
(f/'link').unlink();(f/'link').write_text('broken link');os.chmod(b/'tool',0o600)
# Runtime calls are stubbed; no desktop service is touched by the rehearsal.
original_run=e.subprocess.run
def stub(args,**kw):
 if args[0] in ('systemctl','hyprctl','quickshell'):return subprocess.CompletedProcess(args,0)
 return original_run(args,**kw)
e.subprocess.run=stub;os.environ.pop('HYPRLAND_INSTANCE_SIGNATURE',None);e.restore(s)
assert (f/'original').read_text()=='original' and (f/'link').is_symlink()
assert (f/'extra').read_text()=='user added' and not (f/'new').exists() and not (f/'runtime').exists()
assert (b/'tool').stat().st_mode&0o777==0o755
print('PASS: isolated rollback restores content, links, modes, preserves added files and saves pre-rollback snapshot')
(fonts/'.uuid').unlink();assert e.check_restored(s)['font_cache']==['.local/share/fonts/.uuid']
for file in [fonts/'font.ttf',f/'original']:
 original=file.read_bytes();file.unlink()
 try:e.check_restored(s)
 except RuntimeError:pass
 else:raise AssertionError('Missing font/config must fail validation')
 file.write_bytes(original);os.chmod(file,0o640 if file.name=='original' else 0o644)
(fonts/'.uuid').write_text('modified cache marker')
try:e.check_restored(s)
except RuntimeError:pass
else:raise AssertionError('Changed existing UUID must fail validation')
e.verify(s)
print('PASS: only missing deprecated font UUID cache markers are tolerated; changed markers, missing fonts/configs and backup integrity remain strict')
end4=h/'.config/end4-pC';end4.mkdir();(end4/'config.json').write_text(json.dumps({'osk':{'layout':'Russian'},'background':{'wallpaperPath':'old'},'ui':{'size':12}}))
e.PATHS+=['.config/end4-pC'];original=e.snapshot('original')
(end4/'config.json').write_text(json.dumps({'osk':{'layout':'English'},'background':{'wallpaperPath':'new'},'ui':{'size':12}}))
assert e.check_restored(original,live=True)['generated']==['.config/end4-pC/config.json']
(end4/'config.json').write_text(json.dumps({'osk':{'layout':'English'},'background':{'wallpaperPath':'new'},'ui':{'size':15}}))
try:e.check_restored(original,live=True)
except RuntimeError:pass
else:raise AssertionError('Unrelated preference change must fail validation')
print('PASS: live original-shell wallpaper/layout updates are accepted, unrelated preferences are rejected')
