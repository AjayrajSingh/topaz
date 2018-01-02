# Entity Extraction Script

This is the set of scripts used to extract entities from web pages. They are
injected into web pages loaded by the web view and extract semantic information
that can be used to launch modules related to the web content. They currently
understand JSON-LD and Microdata markup.

## Interface

Once injected the scripts will not expose any JS objects other than a property
`fuchsia:entities` on the _Document_. This contains an array of JSON-LD objects
for each entity found on the page. Entities in Microdata markup are converted to
JSON-LD.

The scripts register for DOM Mutation events so that the page can be re-analyzed
as entities are added and removed. When the entities have changed the
`fuchsia:entities` array will be updated and a _CustomEvent_ named
`fuchsia-entities-changed` will be dispatched on the _Document_.

The web view listens for `fuchsia-entities-changed` and then requests the
`fuchsia:entities` document property.

## Implementation

The entity extraction scripts are written in Typescript. It is bundled for use
with Webpack.

## Build

The prebuilt script will always be in `dist/bundle.js`. To rebuild run:
```
npm install
npm run build
```
