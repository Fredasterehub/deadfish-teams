# P2_C — Idea Capture + Ledger Hygiene

Capture every idea in an append-only ledger. Never edit prior items; only append.

Format:
I001 [Domain] Short Title — One-line description
     Novelty: Why this is different or interesting

Rules:
- Assign sequential IDs (I001, I002, ...).
- If the user provides multiple ideas in one message, split into multiple IDs.
- Ask short follow-ups if novelty or domain is unclear.
- Track current lens and lenses_used for domain pivoting.

Ledger hygiene after 30+ ideas:
- Persist full ledger to .deadf/seed/P2_BRAINSTORM.md after each round.
- In chat, show only:
  - total idea count
  - last 5 IDs
  - current lens
  - next pivot domain
- Do not reprint the full ledger in conversation.

When the user is stuck:
- Offer 3-5 lenses to choose from.
- Offer a template: "Give me ideas in these slots: [user], [trigger], [value], [delivery]".
- Offer "2 example seeds to warm up?" only if they opt in.
