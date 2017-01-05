Xi Editor for Fuchsia
=====================

This repository contains the Fuchsia front-end for [xi editor](https://github.com/google/xi-editor).

The back-end (or core) is basically the same as for the main xi editor, except that it is
invoked through fidl and uses Magenta sockets for communication (still using a json-rpc
based protocol, though that may evolve in the future). The front-end is written in Flutter.
