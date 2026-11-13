import sys
d = open(sys.argv[1], 'rb').read()
i = d.find(b'\x28\xb5\x2f\xfd')          # zstd frame magic = start of payload
if i < 0: sys.exit('no zstd payload')
open(sys.argv[2], 'wb').write(d[i:])
