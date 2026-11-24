---
name: duo-ask
description: Answer a question in depth with two agents from different vendors (Claude Code and Antigravity) that answer independently, debate over hc messages and converge on one answer. Use only when the user invokes /duo-ask or explicitly asks for a duo answer; it starts two extra agents.
argument-hint: "What do you want answered?"
disable-model-invocation: true
---

# Duo ask

Same process as duo-plan, producing an answer instead of a plan. Read
`~/.agents/skills/duo-plan/SKILL.md` and run it exactly, with these differences:

- The text passed to this skill is a question. `brief.md` holds the question in the user's
  words, what a useful answer must cover, pointers, and what is out of scope. Keep your own
  answer out of it.
- Launch with `kind=answer` instead of `kind=plan`.
- Deliver in the conversation instead of copying a file to the project root: the direct answer
  first, the evidence that carries it, then every open disagreement with both positions. Give the
  path of `final.md` for the detail.
- Follow-up questions go to the scribe. When the user is done, clean up as in step 5 of duo-plan;
  nothing stays in the project, so say that `final.md` goes away with it.
