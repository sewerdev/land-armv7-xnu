#!/bin/bash
# The published ARMv7 trees carry the per-arch header directories as real
# copies of the *x86* ones instead of the `machine -> arm` symlinks XNU's
# include paths assume, so `#include <machine/types.h>` lands on the i386 file
# which then asks for `i386/types.h` and the build dies in EXPORT_HDRS.
# Point every `machine` directory at its `arm` sibling in the same parent.
set -u

root="$1"
cd "$root" || exit 1
fixed=0
skipped=0
for m in $(find . -type d -name machine -not -path "./.git/*" | sort); do
    parent=$(dirname "$m")
    if [ -d "$parent/arm" ]; then
        rm -rf "$m"
        ln -s arm "$m"
        echo "symlinked $m -> $parent/arm"
        fixed=$((fixed + 1))
    else
        echo "kept $m (no arm sibling in $parent)"
        skipped=$((skipped + 1))
    fi
done
echo "machine dirs: $fixed symlinked, $skipped kept"

# Some headers were committed with CRLF; a stray \r inside a #line continuation
# or a shebang breaks the build, so normalise the tree once here.
find . -type f \( -name '*.h' -o -name '*.c' -o -name '*.cpp' -o -name '*.defs' \
     -o -name 'Makefile*' -o -name '*.pl' -o -name '*.sh' \) -print0 \
  | xargs -0 sed -i 's/\r$//'
echo "line endings normalised"
