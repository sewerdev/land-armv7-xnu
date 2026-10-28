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
    "\tRC_CFLAGS := -D__arm__ -DARM -DAPPLE -DKERNEL -DKERNEL_PRIVATE "
    "-DXNU_KERNEL_PRIVATE -D__APPLE_API_PRIVATE=1 -D__APPLE_API_UNSTABLE=1 "
    "-Wno-error -Wno-undef-prefix "
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

# The Linux branch resolves setsegname and kextsymboltool through xcrun, and
# neither exists on Linux, so SEG_HACK ends up as a no-op.  The kernel object
# rule then runs `setsegname __KLD obj.o -o obj.o__` followed by
# `mv obj.o__ obj.o`, the no-op leaves no obj.o__, the mv fails, and every
# $(COMPONENT).filelist target dies before the link.  Build the two tools from
# SETUP like the Darwin branch does.  Their sources include Darwin's <libc.h>.
python3 - "$root" <<'PY'
import os
import sys

root = sys.argv[1]

cmd = os.path.join(root, "makedefs", "MakeInc.cmd")
src = open(cmd, encoding="utf-8", errors="surrogateescape").read()
pairs = [
    ("\tSEG_HACK := $(shell $(XCRUN) -sdk $(SDKROOT) -find setsegname)",
     "\tSEG_HACK := $(OBJROOT)/SETUP/setsegname/setsegname"),
    ("\tKEXT_CREATE_SYMBOL_SET := $(shell $(XCRUN) -sdk $(SDKROOT) -find kextsymboltool)",
     "\tKEXT_CREATE_SYMBOL_SET := $(OBJROOT)/SETUP/kextsymboltool/kextsymboltool"),
]
for old, new in pairs:
    if old in src:
        src = src.replace(old, new)
        print("MakeInc.cmd: %s" % new.strip())
    elif new in src:
        print("MakeInc.cmd: already patched (%s)" % new.strip())
    else:
        sys.exit("MakeInc.cmd: line to patch not found: %r" % old[:60])
open(cmd, "w", encoding="utf-8", errors="surrogateescape").write(src)

for name in ("setsegname", "kextsymboltool", "decomment"):
    path = os.path.join(root, "SETUP", name, name + ".c")
    if not os.path.exists(path):
        print("SETUP/%s: source missing, skipping" % name)
        continue
    s = open(path, encoding="utf-8", errors="surrogateescape").read()
    if "#include <libc.h>" in s:
        s = s.replace("#include <libc.h>",
                      "#include <stdio.h>\n#include <stdlib.h>\n#include <unistd.h>")
        open(path, "w", encoding="utf-8", errors="surrogateescape").write(s)
        print("SETUP/%s: replaced Darwin <libc.h> with POSIX headers" % name)
PY

# The tree's C++ link driver still points at the original author's private
# ld64 wrapper, which does not exist here.
python3 - "$root/makedefs/MakeInc.def" <<'PY'
import sys

path = sys.argv[1]
src = open(path, encoding="utf-8", errors="surrogateescape").read()
old = "-fuse-ld=/home/kotu/j1ios/ios7/j1/ld64-wrapper"
new = "-fuse-ld=/usr/local/bin/ld64-wrapper"
if old in src:
    src = src.replace(old, new)
    open(path, "w", encoding="utf-8", errors="surrogateescape").write(src)
    print("MakeInc.def: link driver redirected to /usr/local/bin/ld64-wrapper")
elif new in src:
    print("MakeInc.def: link driver already redirected")
else:
    print("MakeInc.def: no private wrapper path present")
PY
