/*!
 * Copyright 2018 The Fuchsia Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

export function toArray<T extends Node>(list: NodeListOf<T>): Array<T> {
    return Array.prototype.slice.call(list);
}

