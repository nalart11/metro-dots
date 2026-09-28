import sys,pathlib,tempfile,os,json,subprocess
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'scripts'));import snapshot as e
h=pathlib.Path(tempfile.mkdtemp(prefix='hypr-win8-restore-test-'));e.H=h;e.ROOT=h/'snapshots';e.PATHS=['.config/hypr','.local/bin'];e.CONFIGS=['hypr']
f=h/'.config/hypr';f.mkdir(parents=True);(f/'original').write_text('original');os.chmod(f/'original',0o640);(f/'link').symlink_to('original')
b=h/'.local/bin';b.mkdir(parents=True);(b/'tool').write_text('old');os.chmod(b/'tool',0o755)
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
