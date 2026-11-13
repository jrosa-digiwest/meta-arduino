import re, sys
raw = open(sys.argv[1], 'rb').read()
txt = raw.replace(b'\r\n', b'\n').replace(b'\r', b'\n')
txt = re.sub(rb'\x1b\[[0-9;?]*[A-Za-z]', b'', txt)
txt = re.sub(rb'\x1b[()][0-9A-Za-z]', b'', txt)
txt = bytes(c for c in txt if c in (9, 10) or 32 <= c <= 126)
lines = [l.rstrip() for l in txt.decode('ascii').split('\n')]
out, blank = [], False
for l in lines:                      # collapse runs of blank lines
    if not l:
        if blank: continue
        blank = True
    else:
        blank = False
    out.append(l)
open(sys.argv[2], 'w').write('\n'.join(out) + '\n')
print(sys.argv[2], len(out), 'lines')
