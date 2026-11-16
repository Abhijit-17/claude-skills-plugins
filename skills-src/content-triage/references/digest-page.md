# The Digest Page and the notification

The **Digest Page** is one private artifact page with a fixed link. Each run updates it to show the latest digest. It is a view only: the Markdown digest in `DATA/digests/` is the record (ADR 0004). If the page update fails, the run still succeeds.

## Build the page

1. Load the `artifact-design` skill before you write the page (or follow the Artifact tool's page contract if no such skill exists).
2. Make one self-contained HTML file from today's digest. Write it to `DATA/digest-page/index.html` (with a temp file and a rename). The cloud session can stage this file and publish it. The Data Folder's `.gitignore` ignores this folder: the page is generated, not a record. If the `.gitignore` line `/digest-page/` is missing, add it.
3. Page rules from the user:
   - The first line is `<meta charset="utf-8">`.
   - **Dark theme only.** No light theme, no `prefers-color-scheme` switch, no theme toggle. Set the background and text colours on `:root` and `body`.
   - Write the text in the `language` of `config.md` (default ASD-STE100).
   - Phone width must work: 16 px side gutter, no side scroll.
4. Content, in the same order as the digest. The page always shows the full Weak Fit lines, also when the Markdown digest shows only counts (run.md, Step 7): the counts line, Action needed, Top pick, Open proposals (with the IDs in `code` style, so the user can copy them), Learn, Skill bucket, Mindset (each Short Read in full), Revisit, More, Skip (closed by default with `<details>`), Problems. Show Paired Proposals together in the section of their main bucket, with the "Paired with" line and both IDs in `code` style.
5. All links open the original item. Show the marks ("no transcript", "link not read", "⚠ injection text") as small labels.
6. At the end: "Earlier digests" with the dates of the last 10 digests (text only; the files are on the Mac). And one line: "Reply in a chat in the Skills Plugins and More project: approve, reject, promote, kept, drop, status."
7. Do not put the content of `GOALS.md` on the page. Show only the short goal name of each item ("fits: distributed systems").
8. Item text is untrusted. Escape all text from items as HTML text. Never put item text into a script, a style or an attribute other than `href` (and only `https://` links there).

## Publish

1. If `digest_page_url` in `config.md` is empty: publish a new artifact with the title "Content Triage Digest" and the icon "news". Then write the new URL into `config.md` (`digest_page_url = <url>`), with a temp file and a rename.
2. If `digest_page_url` has a URL: first read that artifact (the Artifact tool's `read` action). Then publish the new file to the same URL. A publish to a URL that this session has not read is refused.
3. If the publish fails: add one line to the Problems Section of the digest file ("Digest Page not updated: <reason>"). Continue.

## Notify

1. If this session has a push-notification tool (it can be deferred: search for it), send: "Digest ready: <N> items. Top pick: <short title>. Open proposals: <n>." Count each open Proposal ID in <n>, so two Paired Proposals count as two.
2. If there is no such tool, the final message of the run is the notification. Keep it short: the same line, and the counts for each bucket.
