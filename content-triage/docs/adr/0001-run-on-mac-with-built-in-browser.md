---
status: accepted
---

# A triage run executes linked to AB's Mac and reads sources with the built-in browser

The cloud workspace cannot read YouTube (youtube.com is blocked, and YouTube often blocks transcript requests from cloud servers). X has no free API: reads cost $0.005 for each post (2026 pay-per-use). Thus each triage run is linked to AB's Mac. It reads YouTube and X with the built-in browser of the Claude desktop app, with AB's own sign-ins. The cost is $0 and no API key is necessary.

## Considered Options

- **Cloud-only run with the X API and a widened network allowlist.** Rejected for now: it costs money, and YouTube transcripts are not reliable from cloud servers. This option stays open as a later fallback.

## Consequences

- The Mac must be awake, online, and have the desktop app open at run time. If not, the run fails with a clear message, and the next run catches up from the last item that it saw.
- X does not permit automatic reads. This gives a small risk to AB's X account, so the volume of X reads must stay small.
- A triage run only reads. It never likes, follows, comments, or removes a bookmark or a Watch later video. This keeps AB's accounts unchanged and lowers the risk.
