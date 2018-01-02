/*!
 * Copyright 2018 The Fuchsia Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

export interface Entity {
    [key: string]: string[] | string | Entity[];
};

export interface EntityExtractor {
    /**
     * Extracts entities from the document.
     * Called after load and when the document has changed.
     */
    extract(document: HTMLDocument): Entity[];

    /**
     * Returns true if the {MutationRecord}s provided would affect the set of
     * entities returned by extract. This is called by the mutation observer.
     */
    entitiesChanged(records: MutationRecord[]): boolean;
}
