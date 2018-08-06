// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;

import 'conflict_resolver.dart';

/// Class that resolves conflicts occuring on Ledger pages.
/// Assumes that all the Ledger pages are managed by Sledge.
class ConflictResolverFactory extends ledger.ConflictResolverFactory {
  // If setup has not started, [_setUpCompleted] is null.
  // Otherwise, [_setUpCompleted] contains whether the conflict resolver
  // factory as been succesfully set.
  static Completer<bool> _setUpCompleted;
  static final ledger.ConflictResolverFactoryBinding _factoryBinding =
      new ledger.ConflictResolverFactoryBinding();

  final ledger.ConflictResolverBinding _conflictResolverBinding =
      new ledger.ConflictResolverBinding();
  // The conflict resolver that resolves conflicts for all the pages.
  final ConflictResolver _conflictResolver = new ConflictResolver();

  ConflictResolverFactory._internal();

  /// Registers a conflict resolver with [ledgerInstance].
  /// Returns whether the conflict resolver was succesfully registered.
  static Future<bool> setUpConflictResolver(ledger.Ledger ledgerInstance) {
    if (_setUpCompleted != null) {
      return _setUpCompleted.future;
    }
    _setUpCompleted = new Completer<bool>();
    final wrapper =
        _factoryBinding.wrap(new ConflictResolverFactory._internal());
    ledgerInstance.setConflictResolverFactory(wrapper, (ledger.Status status) {
      if (status != ledger.Status.ok) {
        throw new Exception(
            'Sledge failed to SetConflictResolverFactory ($status)');
        _setUpCompleted.complete(false);
      } else {
        _setUpCompleted.complete(true);
      }
    });
    return _setUpCompleted.future;
  }

  @override
  void getPolicy(
      ledger.PageId pageId, void callback(ledger.MergePolicy policy)) {
    callback(ledger.MergePolicy.automaticWithFallback);
  }

  @override
  void newConflictResolver(ledger.PageId pageId,
      InterfaceRequest<ledger.ConflictResolver> resolver) {
    // TODO: check that [pageId] is a page managed by Sledge.
    _conflictResolverBinding.bind(_conflictResolver, resolver);
  }
}
