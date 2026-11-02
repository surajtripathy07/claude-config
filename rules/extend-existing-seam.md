# Extend the existing seam

Before adding a new method, constant, or class method to make a variation possible, find
how the codebase already expresses the nearest variation of the same kind and extend that.
Look for the sibling: a delegator that remaps methods, a `*_for_<flow>` naming pattern, a
configuration object that the factory merely selects.

Signs you picked the wrong seam:

- A new guard that duplicates one already present a few lines away.
- A new public method on a model whose only job is to dispatch to a collaborator.
- A paragraph under `doc/architecture/` (or the project's equivalent) that you had to edit
  because the code no longer matches what it describes.

When any of these appear, stop and ask where the codebase already stores this kind of
per-product or per-flow configuration, then put the change there.
