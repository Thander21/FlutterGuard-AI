---
spec_version: "openspec-1.0"
id: "SYS-NN-000"
title: "Short system contract title"
status: "draft"
kind: "system"
---

# 1. Problem

What breaks without this contract: the subsystem gap, who consumes it,
and the smallest observable misbehavior it must prevent.

# 2. Interface / Schema

Commands, wire formats, or APIs with exact names, arguments, and return
shapes. Name new dependencies here (none allowed without amending this
spec).

# 3. File Placement

Every file this contract creates or touches, and why it lives there.
System specs never land as top-level `specs/*.md` (the grader throws on
specs without `failing:`/`passing:` front-matter).

# 4. Evidence Wiring

Which `evidence.jsonl` keys this contract emits or consumes, and the exact
moment each entry is appended.

# 5. Errors and Edges

Failure modes, timeouts, rollback behavior, and boundary conditions with
the expected outcome of each.

# 6. Contradictions Resolved

Doc contradictions this contract settles, with the losing variant named
as superseded.
