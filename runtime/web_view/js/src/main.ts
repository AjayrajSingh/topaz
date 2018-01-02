/*!
 * Copyright 2018 The Fuchsia Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import { MicrodataExtractor } from "./microdata";
import { JsonLdExtractor } from "./jsonld";
import { Entity, EntityExtractor } from "./entity";

class SchemaOrgEntityExtractor implements EntityExtractor {
    /**
     * List of {EntityExtractor} instances.
     */
    private readonly extractors = [
        new MicrodataExtractor(), new JsonLdExtractor(),
    ];

    /**
     * Map of {EntityExtractor} instances to up to date arrays of extracted entities.
     * If an EntityExtractor is missing calling extract() will fill it in.
     */
    private readonly entityCache = new Map<EntityExtractor, Array<Entity>>();

    /**
     * A {MutationObserver} that watches for changes related to Schema.org markup.
     */
    private readonly observer = new MutationObserver((records) => {
        if (this.entitiesChanged(records)) {
            this.updateEntities();
        }
    });

    constructor() {
        this.observer.observe(document, {
            childList: true,
            attributes: true,
            subtree: true,
            characterData: true,
            attributeOldValue: true,
        });
        this.updateEntities();
    }

    /**
     * Calls inner {EntityExtractor}s to fill the entityCache as required.
     * @param document The document to extract from.
     */
    public extract(document: HTMLDocument): Entity[] {
        for (const x of this.extractors) {
            if (!this.entityCache.has(x)) {
                this.entityCache.set(x, x.extract(document));
            }
        }
        let entities = new Array<Entity>();
        this.entityCache.forEach(ents => entities.push(...ents));
        return entities;
    }

    /**
     * Calls inner {EntityExtractor}s and clear the entityCache if any indicate
     * that their entities have changed.
     * @param records records of document mutations.
     */
    public entitiesChanged(records: MutationRecord[]): boolean {
        let changed = false;
        for (const x of this.extractors) {
            if (x.entitiesChanged(records)) {
                changed = true;
                // Clear the cache entry for this extractor.
                this.entityCache.delete(x);
            }
        }
        return changed;
    }

    /**
     * Update the fuchsia:entities field on the document and dispatch a
     * fuchsia-entities-changed {Event}.
     */
    private updateEntities() {
        (document as any)['fuchsia:entities'] = this.extract(document);
        document.dispatchEvent(new CustomEvent('fuchsia-entities-changed'));
    }
}

const extractor = new SchemaOrgEntityExtractor();
