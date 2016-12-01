Fuchsia Web View
=======================================

This repository contains the Fuchsia-specific code wrapping the web view class from third_party/webkit/Source/WebKit/fuchsia/WebView.h.

Before building this package you must follow the build instructions at https://fuchsia.googlesource.com/third_party/webkit/

After that

        ./packages/gn/gen.py -m default,web_view
        ./buildtools/ninja -C out/debug-x86-64
        ./magenta/scripts/run-magenta-x86-64 -g -x out/debug-x86-64/user.bootfs

Once in mxsh

        @ bootstrap launch web_view
