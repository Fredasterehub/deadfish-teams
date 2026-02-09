# Idea Capture and Ledger Hygiene

Capture ideas in an append-only ledger.

Format:
I001 [Domain] Short Title - One-line description
     Novelty: why this differs from obvious alternatives

Rules:
- Sequential IDs (`I001`, `I002`, ...).
- Split multi-idea user replies into separate IDs.
- Ask short follow-up questions when domain or novelty is ambiguous.

Ledger hygiene after 30+ ideas:
- Persist full ledger to `docs/design/BOOTSTRAP_BRAINSTORM.md` each round.
- In conversation, show only:
  - total idea count
  - last 5 IDs
  - current lens
  - next pivot domain

When user is stuck:
- offer 3-5 lenses
- offer a slot template: user, trigger, value, delivery
- optionally offer two seed examples
