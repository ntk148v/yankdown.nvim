# Graph Report - . (2026-07-11)

## Corpus Check

- 16 files · ~172,340 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary

- 53 nodes · 68 edges · 8 communities detected
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## God Nodes (most connected - your core abstractions)

1. `probe()` - 5 edges
2. `M.check()` - 5 edges
3. `M.start()` - 4 edges
4. `M.setup()` - 4 edges
5. `M.insert()` - 3 edges
6. `M.provider()` - 3 edges
7. `M.ok()` - 3 edges
8. `M.format()` - 3 edges
9. `maybe_intercept()` - 3 edges
10. `direction()` - 2 edges

## Surprising Connections (you probably didn't know these)

- None detected - all connections are within the same source files.

## Communities

### Community 0 - "Community 0"

Cohesion: 0.2
Nodes (0):

### Community 1 - "Community 1"

Cohesion: 0.38
Nodes (8): add(), env_set(), executable(), M.check(), M.format(), M.ok(), M.warn_if_missing(), probe()

### Community 2 - "Community 2"

Cohesion: 0.33
Nodes (5): direction(), lines(), M.insert(), M.start(), warn_once()

### Community 3 - "Community 3"

Cohesion: 0.32
Nodes (3): executable(), M.provider(), M.read_html()

### Community 4 - "Community 4"

Cohesion: 0.39
Nodes (5): intercept_buffer(), M.setup(), map_plug(), maybe_create_commands(), maybe_intercept()

### Community 5 - "Community 5"

Cohesion: 0.4
Nodes (0):

### Community 6 - "Community 6"

Cohesion: 1.0
Nodes (0):

### Community 7 - "Community 7"

Cohesion: 1.0
Nodes (0):

## Knowledge Gaps

- **Thin community `Community 6`** (2 nodes): `convert.lua`, `M.html_to_markdown()`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 7`** (1 nodes): `run.lua`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions

_Not enough signal to generate questions. This usually means the corpus has no AMBIGUOUS edges, no bridge nodes, no INFERRED relationships, and all communities are tightly cohesive. Add more files or run with --mode deep to extract richer edges._
