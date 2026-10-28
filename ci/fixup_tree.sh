#!/bin/bash
# Tree fixups applied before building the ARMv7 kernel on Linux.
#
# makedefs defines __arm__/ARM only when TARGET_CONFIGS happens to carry ARM as
# its second word.  The machine-independent header-export stage runs with
# MACHINE_CONFIG=DEFAULT, so that condition is false, `__arm__` is missing,
# every `machine/foo.h` dispatcher falls through to the i386 branch, and the
# build dies in EXPORT_HDRS before a single kernel file is compiled.  Drop the
# gate: everything this branch builds is ARMv7.
set -eu

root="$1"
cd "$root"

find . -type f \( -name '*.h' -o -name '*.c' -o -name '*.cpp' -o -name '*.defs' \
     -o -name 'Makefile*' -o -name 'MakeInc*' -o -name '*.pl' -o -name '*.sh' \
     -o -name '*.cmd' -o -name '*.rule' -o -name '*.dir' -o -name 'files*' \) -print0 \
  | xargs -0 sed -i 's/\r$//'
echo "line endings normalised"

python3 - "$root/makedefs/MakeInc.def" <<'PY'
import sys

path = sys.argv[1]
src = open(path, encoding="utf-8", errors="surrogateescape").read()

gated = (
    "\tifeq ($(word 2, $(TARGET_CONFIGS_UC)),ARM)\n"
    "\t\tBUILD_NO_DEBUG := 1\n"
    "        RC_CFLAGS := -D__arm__ -DARM\n"
    "\tendif\n"
)
open_gate = (
    "\t# Every target built by this branch is ARMv7, and the header-export\n"
    "\t# stage runs before TARGET_CONFIGS names a machine config, so these\n"
    "\t# defines cannot be gated on it.  The extra -I roots are where the HD2\n"
    "\t# headers live: they are included by bare name from other components.\n"
    "\tBUILD_NO_DEBUG := 1\n"
    "\tRC_CFLAGS := -D__arm__ -DARM -Wno-error -Wno-undef-prefix "
    "-I$(SRCROOT)/osfmk/kern -I$(SRCROOT)/osfmk/ipc "
    "-I$(SRCROOT)/iokit/Drivers/KernelBuiltIn/ARM/AppleARMPlatform "
    "-I$(SRCROOT)/pexpert/arm -I$(SRCROOT)/bsd/dev/arm\n"
)

if gated in src:
    src = src.replace(gated, open_gate)
    open(path, "w", encoding="utf-8", errors="surrogateescape").write(src)
    print("MakeInc.def: __arm__/ARM no longer gated on TARGET_CONFIGS")
elif "RC_CFLAGS := -D__arm__ -DARM" in src and "TARGET_CONFIGS_UC)),ARM" not in src:
    print("MakeInc.def: already patched")
else:
    lines = src.splitlines()
    for i, l in enumerate(lines):
        if "RC_CFLAGS" in l:
            print("context:", "\n".join(lines[max(0, i - 4):i + 4]))
            break
    sys.exit("MakeInc.def: expected RC_CFLAGS block not found; adapt the patch")
PY

# osfmk/kdp/kdp.c dereferences struct mem_and_io_snapshot and uses the
# STACKSHOT_* constants, but the published export carries no bsd/sys/stackshot.h.
if [ ! -e "$root/bsd/sys/stackshot.h" ]; then
    cidir="${2:-$(dirname "$(readlink -f "$0")")}"
    install -m 644 "$cidir/tree/bsd_sys_stackshot.h" "$root/bsd/sys/stackshot.h"
    echo "restored bsd/sys/stackshot.h"
else
    echo "bsd/sys/stackshot.h already present"
fi
