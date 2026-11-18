#!/bin/sh
# Command Line Tools ship swift-testing outside the default search path.
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
cd "$(dirname "$0")/.." && swift test -Xswiftc -F$F -Xlinker -F$F -Xlinker -rpath -Xlinker $F "$@"
