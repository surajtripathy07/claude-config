---
name: git-commit
description: Writes git commit messages. Use when creating a git commit, ammending commits, rebasing commits
model: haiku
---

When writing commits:

- Add detail about the changes being made.
  - What
  - Why
- Add detail about the bead/issue/task that is the parent of this change
- Add detail about type of this commit
  - type::feature
  - type::bugfix
  - type::maintainence
- Add details about the amount of user involvement in the actual code change
  - Fully automated (supervision::low)
  - User reviewed, suggested changes (supervision::med)
  - User prompted, controlled (supervision::high)
- Add model :bot: 
