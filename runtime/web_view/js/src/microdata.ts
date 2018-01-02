/*!
 * Copyright 2018 The Fuchsia Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import { EntityExtractor, Entity } from "./entity";
import { toArray } from "./util";

const asciiSpaces = /[ \r\n\t\f]+/;

export class MicrodataExtractor implements EntityExtractor {
    public extract(document: HTMLDocument): Entity[] {
        const entities: Entity[] = [];
        for (const node of toArray(document.querySelectorAll('*[itemscope]:not([itemprop])'))) {
            entities.push(this.extractEntity(node, []));
        }

        return entities;
    }

    /**
     * Returns true if the target element is the direct child from a microdata perspective.
     * @param element The target element
     * @param root The root element
     */
    private directChild(element: Element, root: Element): boolean {
        for (let e = element.parentElement; e; e = e.parentElement) {
            if (e == root) {
                return true;
            }
            if (e.hasAttribute('itemscope')) {
                return false;
            }
        }
        return false;
    }

    private itemRefs(root: Element): string[] {
        // Find itemrefs on the root.
        const itemrefs = (root.getAttribute('itemref') || "").split(asciiSpaces);

        // Find itemrefs on the children.
        for (const e of toArray(root.querySelectorAll('[itemref]')).filter(r => this.directChild(r, root))) {
            for (const i of e.getAttribute('itemref')!.split(asciiSpaces)) {
                itemrefs.push(i);
            }
        }

        return itemrefs;
    }

    private itemProperties(root: Element): Element[] {
        // Get all the itemprop children...
        const props = toArray(root.querySelectorAll('[itemprop]:not([itemprop=""])'))
            // that are direct children...
            .filter(prop => this.directChild(prop, root));

        if (root.hasAttribute('itemscope') && root.hasAttribute('itemref')) {
            for (const itemref of root.getAttribute('itemref')!.split(asciiSpaces)) {
                const element = document.getElementById(itemref);
                if (!element) {
                    continue;
                }
                for (const prop of this.itemProperties(element)) {
                    props.push(prop);
                }
            }
        }

        return props;
    }

    private propertyValue(element: Element, memory: Element[]): Entity | string {
        memory = memory || [];
        if (memory.indexOf(element) != -1) {
            return 'ERROR';
        }

        if (element.hasAttribute('itemscope')) {
            return this.extractEntity(element, memory);
        }
        if (element.hasAttribute('content')) {
            return element.getAttribute('content')!;
        }
        if (element instanceof HTMLAudioElement ||
            element instanceof HTMLEmbedElement ||
            element instanceof HTMLIFrameElement ||
            element instanceof HTMLImageElement ||
            element instanceof HTMLSourceElement ||
            element instanceof HTMLTrackElement ||
            element instanceof HTMLVideoElement) {
            return element.src || "";
        }
        if (element instanceof HTMLAnchorElement ||
            element instanceof HTMLAreaElement ||
            element instanceof HTMLLinkElement) {
            return element.href || "";
        }
        if (element instanceof HTMLMeterElement ||
            element instanceof HTMLDataElement) {
            if (element.hasAttribute('value')) {
                return element.getAttribute('value')!;
            }
        } else if (element instanceof HTMLTimeElement) {
        //} else if (element.tagName == 'TIME') {
            if (element.hasAttribute('datetime')) {
                return element.getAttribute('datetime')!;
            }
        }
        return element.textContent || "";

    }

    private extractEntity(item: Element, memory: Element[]): Entity {
        // 1. Let result be an empty object.
        let result: Entity = {};

        // 2. If no memory was passed to the algorithm, let memory be an empty
        //    list.
        memory = memory || [];

        // 3. Add item to memory.
        memory.push(item);

        // 4. If the item has any item types, add an entry to result called
        //    "@type" whose value is an array listing the item types of item, in
        //    the order they were specified on the itemtype attribute.
        const itemTypes = item.getAttribute('itemtype');
        if (itemTypes) {
            result['@type'] = itemTypes.split(asciiSpaces);

        }

        // 5. If the item has a global identifier, add an entry to result called
        //    "@id" whose value is the global identifier of item.
        if (item.hasAttribute('itemid')) {
            result['@id'] = item.getAttribute('itemid')!;
        }

        // 7. For each element element that has one or more property names and is
        //    one of the properties of the item item, in the order those elements
        //    are given by the algorithm that returns the properties of an item,
        //    run the following substeps:
        for (const element of this.itemProperties(item)) {
            const value = this.propertyValue(element, memory);
            for (const name of element.getAttribute('itemprop')!.split(asciiSpaces)) {
                if (!result[name]) {
                    result[name] = [];
                }
                (result[name] as Array<string | Entity>).push(value);
            }
        }
        return result;
    }

    private isMicrodataRelated(node: Node): boolean {
        if (node instanceof Element) {
            return node.hasAttribute('itemscope')
                || node.hasAttribute('itemprop')
                || node.hasAttribute('itemtype')
                || node.hasAttribute('itemid')
                || node.hasAttribute('itemref');
        }
        if (node.parentElement) {
            return this.isMicrodataRelated(node.parentElement);
        }
        return false;
    }

    public entitiesChanged(records: MutationRecord[]): boolean {
        for (const record of records) {
            if (record.type === "childList") {
                for (const node of toArray(record.addedNodes)) {
                    if (this.isMicrodataRelated(node)) {
                        return true;
                    }
                }
                for (const node of toArray(record.removedNodes)) {
                    if (this.isMicrodataRelated(node)) {
                        return true;
                    }
                }
            } else if (record.type === "attributes") {
                // TODO: if oldValue means target is no longer related...
                // TODO: if id changes to itemref moves...
                return this.isMicrodataRelated(record.target);
            } else if (record.type === "characterData") {
                return this.isMicrodataRelated(record.target);
            }
        }
        return false;
    }

}
