/*!
 * Copyright 2018 The Fuchsia Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import { EntityExtractor, Entity } from "./entity";
import { toArray } from "./util";

const jsonLdType = 'application/ld+json';

export class JsonLdExtractor implements EntityExtractor {
    extract(document: HTMLDocument): Entity[] {
        const entities: Entity[] = [];
        for (var script of toArray(document.querySelectorAll("script[type='application/ld+json']"))) {
            var value;
            try {
                value = JSON.parse(script.textContent!);
            } catch (e) {
                continue;
            }
            if (value instanceof Array) {
                entities.push(...value);
            } else {
                entities.push(value);
            }
        }
        return entities;
    }

    private isJsonLdRelated(node: Node): boolean {
        if (node.nodeType != Node.ELEMENT_NODE) {
            if (node.parentNode) {
                return this.isJsonLdRelated(node.parentNode);
            } else {
                return false;
            }
        }

        return node instanceof HTMLScriptElement && node.type === jsonLdType;
    }

    entitiesChanged(records: MutationRecord[]): boolean {
        for (const record of records) {
            if (record.type === "childList") {
                for (const node of toArray(record.addedNodes)) {
                    if (this.isJsonLdRelated(node)) {
                        return true;
                    }
                }
                for (const node of toArray(record.removedNodes)) {
                    if (this.isJsonLdRelated(node)) {
                        return true;
                    }
                }
            } else if (record.type === "attributes") {
                if (record.target instanceof HTMLScriptElement) {
                    if (record.target.type === jsonLdType || record.oldValue === jsonLdType) {
                        return true;
                    }
                }
            } else if (record.type === "characterData") {
                return this.isJsonLdRelated(record.target);
            }
        }
        return false;
    }
}
