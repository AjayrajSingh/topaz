# Topaz directory structure

This document describes the directory structure of this repository.

[TOC]

## Common parts

Topaz follows the common aspects of layer repository structure defined in
[Layer repository structure](https://fuchsia.googlesource.com/docs/+/master/layer_repository_structure.md).

This file documents the Topaz-specific pieces.

## public/dart-pkg/

The `public/dart-pkg/` directory contains Dart packages that do not have
corresponding libraries in other languages. For example, this directory contains
the packages that define the Fuchsia-specific interface between the Dart code
and the Dart runtime.

Dart packages that have corresponding libraries in other languages should be in
`public/lib` along side the implementations in those other languages.
