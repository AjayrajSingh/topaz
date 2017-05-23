Fuchsia Web View
=======================================

This repository contains the Fuchsia-specific code wrapping the web view class from third_party/webkit/Source/WebKit/fuchsia/WebView.h.

The build is integrated into the normal Fuchsia build process, but due to its
heft  it's disabled by default.  If you want to use the web_view component in
your image, enable it by adding 'web_view' to your build configuration, i.e. by
running
```
./packages/gn.gen.py -m default,web_view

# or (if you're using env.sh)
fset x86-64 --modules default,web_view
```
