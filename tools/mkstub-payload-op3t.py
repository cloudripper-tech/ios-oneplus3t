#!/usr/bin/env python3
import struct, sys

VIRT = 0xfffffff007004000
PHYS = 0x100000000           # OnePlus 3T upper DDR bank
MEM = 0xfcc00000
FILL_OFF = 0x100000
M64 = (1 << 64) - 1

stub = open(sys.argv[1], 'rb').read()
fill_len = (int(sys.argv[3]) if len(sys.argv) > 3 else 24) << 20
assert len(stub) <= FILL_OFF

x, words = 0x2545F4914F6CDD1D, []
for _ in range(fill_len // 8):
    x ^= (x << 13) & M64; x ^= x >> 7; x ^= (x << 17) & M64
    words.append(x)
fill = struct.pack(f'<{len(words)}Q', *words)
s = 0
for w in words:
    s = (s * 31 + w) & M64

adt = b'STUBADT\0' * 2
cmdline = f'stub sum={s:x} len={fill_len:x}'.encode().ljust(608, b'\0')
hdr_len = 0x2a8 + 2 * 32
stub_off = (hdr_len + 15) & ~15
fill_off = (stub_off + len(stub) + 15) & ~15
adt_off = fill_off + fill_len
kernel_end = VIRT + FILL_OFF + fill_len
segs = [(VIRT, len(stub), stub_off, len(stub)),
        (VIRT + FILL_OFF, fill_len, fill_off, fill_len)]
hdr = struct.pack('<8sII7Q', b'SWEETXNU', 1, len(segs), VIRT, VIRT, adt_off,
                  len(adt), kernel_end, PHYS, MEM) + cmdline
hdr += b''.join(struct.pack('<4Q', *sg) for sg in segs)
assert len(hdr) == hdr_len
out = hdr.ljust(stub_off, b'\0') + stub
out = out.ljust(fill_off, b'\0') + fill + adt
open(sys.argv[2], 'wb').write(out)
print(f'{sys.argv[2]}: {len(out)} bytes, expect sum {s:016x}')
