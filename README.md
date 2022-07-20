# Delta

## Installation

Delta is a fast distributed schema-less document-oriented JSON database written in Elixir, where all updates to documents are represented as a changes to a certain path.

## Purpose

The purpose of the database is to provide developers with tool to build document-oriented application with soft-realtime distributed history features

## Principles and capabilities

### Documents and collections

As it was stated before, Delta is a document-oriented DB, which means that data is stored in a single *document* without relationships as opposed to a number of SQL tables and relationships.

In Delta, *documents* to not have schema, which means there is no restriction on how your data should be structured.

Each *document* belongs to a *collection* which are meant to be a way to organize your *documents* and to serve as a pseudo-datatype.

![Entity-Relationship diagram](docs/entety-relationship.drawio.svg)

### Changes

Any write operations are represented by *change*. *Change* belongs to concrete *document* and specifies what is changed via JSONPath `path`, a `value` of a *change* and reference to a `previous` *change* `id` and also its `kind`.

`kind` is one of the following:

- `update` – updates document with value at a given path. If some parts of the path do not exist, they will be created*.
- `delete` – deletes value at a given path from document. Ignores `value` of the change.
- `add` – adds element to the start of a list at a given path. If some parts of the path do not exists, they will be created. If path does not point to a list, works as `update`.
- `remove` – removes first occurrence of a value from the list at a given path. If path does not point to a list, works as `delete`

Note that working with elements of a list via `update` and `delete` and a `path` to element is possible, but may lead to conflicts during synchronization. It is recommended to treat lists as unordered collections.

Changes have an optional `meta` field, in which metadata of a change should be stored (e.g. user that made the change)

### Reading the document

Document can be read as a whole using `get(collection_id, document_id)` of your driver or as a part by passing `path` in `get(collection_id, document_id, path)`

### Path

Consider the following document

```json
{ "store": {
    "book": [
      { "category": "reference",
        "author": "Nigel Rees",
        "title": "Sayings of the Century",
        "price": 8.95
      },
      { "category": "fiction",
        "author": "Evelyn Waugh",
        "title": "Sword of Honour",
        "price": 12.99
      },
      { "category": "fiction",
        "author": "Herman Melville",
        "title": "Moby Dick",
        "isbn": "0-553-21311-3",
        "price": 8.99
      },
      { "category": "fiction",
        "author": "J. R. R. Tolkien",
        "title": "The Lord of the Rings",
        "isbn": "0-395-19395-8",
        "price": 22.99
      }
    ],
    "bicycle": {
      "color": "red",
      "price": 19.95
    }
  }
}
```

We can query and modify this document with paths as shown below

| path        | get            | update with 42      | add 42                               | delete                  | remove                         |
| ----------- | -------------- | ------------------- | ------------------------------------ | ----------------------- | ------------------------------ |
| $           | whole document | 42                  | 42                                   | can not be deleted      | can not be deleted             |
| .store.book | list of books  | {store: {book: 42}} | {store: {book: [42, list of books]}} | {store: {bicycle: ...}} | {store: {book: list of books}} |

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
