# Project Instructions

- After making project changes, run the relevant validation, create descriptive commits, and push them to `origin` (`git@github.com:YicongCao/Brushline-Rally.git`). The user explicitly requests this for future edits as well.
- Do not force-push, amend existing commits, or include unrelated user changes. Report any validation or push failures rather than claiming success.
- Batch implementation and validation where practical to conserve the user's token budget; avoid repetitive per-step reviews.
- Before finishing project changes, synchronize the validated, committed result into the user's regular checkout at `/Users/cong/Documents/Projects/Art-Rally` (`~/Documents/Projects/Art-Rally`), even when working in a Codex worktree.
- Check both checkouts' status and ancestry first. Prefer a fast-forward merge into the regular checkout's existing branch. Preserve local edits and commits; never overwrite files, hard-reset, or force-push to synchronize. If a safe synchronization is blocked, report the exact blocker instead of claiming the directories match.
- Verify the regular checkout contains the delivered commit and, when runtime assets changed, refresh Godot imports there. Report synchronization status in the final response and use the regular checkout path in player-facing launch commands.

- For Art Rally menu, HUD, and replay UI changes, read `.agents/skills/art-rally-ui/SKILL.md` and apply its vector icon, concise label, and persistent selection conventions.
