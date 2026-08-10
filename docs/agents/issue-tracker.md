# Issue Tracker

Specifications and implementation tickets published by the Matt Pocock engineering
skills live in this repository's GitHub Issues:
`Parz1val1/rhythm-game-prototype`.

Before an external operation, run `gh auth status`. The Codex filesystem sandbox
may not see the Windows keyring; if sandboxed status fails, retry with approved
unsandboxed execution before treating authentication as unavailable. When status
succeeds and the task authorizes the write, use `gh` from this checkout so it
infers the repository from `origin`. If host authentication is unavailable, return
the issue/spec as a local draft and ask the user to authenticate before publishing.

- Create: `gh issue create --title "..." --body-file <path>`
- Read: `gh issue view <number> --comments`
- List: `gh issue list --state open`
- Comment: `gh issue comment <number> --body-file <path>`

When a skill says **publish to the issue tracker**, create a GitHub issue. When it
says **fetch the ticket**, read the referenced GitHub issue and its comments.

Pull requests are not an issue-triage surface for this repository. External writes
still require the authorization implied by the user's task; otherwise prepare the
issue content locally for review.
