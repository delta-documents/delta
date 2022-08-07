# Delta

## Installation

Delta is a fast distributed schema-less document-oriented JSON history service written in Elixir, where all updates to documents are represented as a [RFC 6092](https://www.rfc-editor.org/rfc/rfc6902.html)-like deltas called changes

## Purpose

The purpose of the database is to provide developers with tool to build document-oriented application with soft-realtime distributed history features

## Principles and capabilities

### Documents and collections

As it was stated before, Delta is a document-oriented DB, which means that data is stored in a single *document* without relationships as opposed to a number of SQL tables and relationships.

In Delta, *documents* to not have schema, which means there is no restriction on how your data should be structured.

Each *document* belongs to a *collection* which are meant to be a way to organize your *documents* and to serve as a pseudo-datatype.

![Entity-Relationship diagram](docs/entety-relationship.drawio.svg)

### Changes

### Reading the document

Document can be read as a whole using `get(collection_id, document_id)` of your driver or as a part by passing `path` in `get(collection_id, document_id, path)`

### History

Each document has zero or more changes associated with it thus forming history of changes.
History is a list of changes linked via `previous` attribute of a change. Changes may be added but never modified or deleted.

### Subscriptions

Each client can subscribe to changes of a particular document

### Synchronization

To be implemented

## API

Subject to change

## Drivers

To be implemented

## Scaling

To be implemented

## Running

1. [Instal Elixir](https://elixir-lang.org/install.html#distributions)
2. `git clone https//githuhb.com/florius0/delta && cd delta`
3. `mix run --no-halt`

## Installation as mix dependency

```elixir
def deps do
  [
    {:delta, github: "florius0/delta"}
  ]
end
```
