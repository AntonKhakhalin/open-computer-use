# Design Docs Index

Use this directory to centrally manage architecture and product design documents.

Suggested conventions:

- One document per topic.
- Each document states its current status and a short summary.
- Link the execution plan or spec that introduced it.

## Initial documents

- `core-beliefs.md`
- `macos-window-identity.md`: macOS window2 window identity resolution — investigation findings for same-bounds window AX tree mismatch and closed-window ghosts (leftover CGWindow entries), the identity scheme (`_AXUIElementGetWindow` SPI + explicit ambiguity error + AX-identity liveness check), and the guarantees.
