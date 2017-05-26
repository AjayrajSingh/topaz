Fuchsia Web View
=======================================

This repository contains the Fuchsia-specific code wrapping the web view class from third_party/webkit/Source/WebKit/fuchsia/WebView.h.

The build is integrated into the normal Fuchsia build process, but due to its
heft the default build uses prebuilt artifacts for webkit itself. To build all
dependencies locally, add 'use_prebuilt_webkit=false' to your GN arguments and
add 'webkit' to your module set:

```
./packages/gn.gen.py -m default,webkit --args use_prebuilt_webkit=false

# or (if you're using env.sh)
fset x86-64 --modules default,webkit --args use_prebuilt_webkit=false
```
