#!/bin/bash
# Build the OnePlus 3T shim: start.S + oneplus3t.c + pstore.c + console.c, wrapped in
# a stock-style v0 boot.img by tools/mkboot-v0.sh.
# Usage: [WDT_SECS=120] shim/build-oneplus3t.sh STOCK_BOOT.img [PAYLOAD]   -> shim/out/oneplus3t-boot.img
set -euo pipefail
stock=$(realpath "$1")
payload=${2:+$(realpath "$2")}
cd "$(dirname "$0")"

# Toolchain detection: try clang first (with lld), fallback to aarch64 gcc
if command -v clang >/dev/null && command -v ld.lld >/dev/null; then
	CC="clang --target=aarch64-linux-gnu"
	LD="ld.lld"
	OBJCOPY="llvm-objcopy"
	NM="llvm-nm"
	READELF="llvm-readelf"
elif command -v aarch64-linux-gnu-gcc >/dev/null; then
	CC="aarch64-linux-gnu-gcc"
	LD="aarch64-linux-gnu-ld"
	OBJCOPY="aarch64-linux-gnu-objcopy"
	NM="aarch64-linux-gnu-nm"
	READELF="aarch64-linux-gnu-readelf"
elif command -v aarch64-elf-gcc >/dev/null; then
	CC="aarch64-elf-gcc"
	LD="aarch64-elf-ld"
	OBJCOPY="aarch64-elf-objcopy"
	NM="aarch64-elf-nm"
	READELF="aarch64-elf-readelf"
else
	echo "error: No suitable aarch64 compiler found" >&2
	exit 1
fi

CFLAGS="-O2 -ffreestanding -nostdlib -fno-pic -mgeneral-regs-only -mstrict-align -fno-stack-protector -Wall -Wextra -DONEPLUS3T -DWDT_SECS=${WDT_SECS:-120}"

mkdir -p out/oneplus3t
for f in start.S oneplus3t.c pstore.c console.c fdt.c loader.c; do
	$CC $CFLAGS -c $f -o out/oneplus3t/${f%.*}.o
done

# Verify no absolute 64-bit relocations in C objects
abs=$($READELF -r out/oneplus3t/oneplus3t.o out/oneplus3t/pstore.o out/oneplus3t/console.o out/oneplus3t/fdt.o out/oneplus3t/loader.o | grep -c ABS64 || true)
[ "$abs" = 0 ] || { echo "error: $abs absolute relocations in C objects" >&2; exit 1; }

if [ "$LD" = "ld.lld" ]; then
	$LD -T shim.ld --build-id=none -N \
		out/oneplus3t/start.o out/oneplus3t/oneplus3t.o out/oneplus3t/pstore.o out/oneplus3t/console.o out/oneplus3t/fdt.o out/oneplus3t/loader.o -o out/oneplus3t/shim.elf
else
	$CC $CFLAGS -static -T shim.ld -Wl,--build-id=none -Wl,--no-warn-rwx-segments -Wl,-N \
		out/oneplus3t/start.o out/oneplus3t/oneplus3t.o out/oneplus3t/pstore.o out/oneplus3t/console.o out/oneplus3t/fdt.o out/oneplus3t/loader.o -o out/oneplus3t/shim.elf
fi

$OBJCOPY -O binary out/oneplus3t/shim.elf out/oneplus3t/Image
size=$($NM out/oneplus3t/shim.elf | awk '$3=="_end"{print $1}')
truncate -s $((16#$size)) out/oneplus3t/Image
[ -z "$payload" ] || cat "$payload" >> out/oneplus3t/Image

mkdir -p out
../tools/mkboot-v0.sh "$stock" out/oneplus3t/Image out/oneplus3t-boot.img
echo "Successfully built out/oneplus3t-boot.img"

# Loader test "kernel" (shim/stub.c)
$CC $CFLAGS -c stub.c -o out/oneplus3t/stub.o
if [ "$LD" = "ld.lld" ]; then
	$LD -T shim.ld --build-id=none -N \
		out/oneplus3t/stub.o out/oneplus3t/pstore.o out/oneplus3t/console.o -o out/oneplus3t/stub.elf
else
	$CC $CFLAGS -static -T shim.ld -Wl,--build-id=none -Wl,--no-warn-rwx-segments -Wl,-N \
		out/oneplus3t/stub.o out/oneplus3t/pstore.o out/oneplus3t/console.o -o out/oneplus3t/stub.elf
fi
$OBJCOPY -O binary out/oneplus3t/stub.elf out/oneplus3t/stub.bin
stub_size=$($NM out/oneplus3t/stub.elf | awk '$3=="_end"{print $1}')
truncate -s $((16#$stub_size)) out/oneplus3t/stub.bin
echo "Successfully built out/oneplus3t/stub.bin"
