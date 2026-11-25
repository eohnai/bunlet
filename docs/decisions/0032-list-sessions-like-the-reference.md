# 0032: List sessions the way the reference island does

- Status: accepted
- Date: 2026-11-25
- Amends: [0022](0022-close-reference-settings-gaps.md)

## Context

Unknown sessions stayed in the island indefinitely. The idle-session clean-up from 0022 hid only Idle and Ended sessions,
so an Unknown row stayed until the user removed it. A provider's quota badge also disappeared when its only sessions were
Unknown or Ended. The reference island, compared on 2026-11-25 in
[reference adoption](../notes/reference-adoption.md#session-visibility), has no Unknown state:

- It always shows a session waiting for approval or an answer.
- It hides a hook-tracked session once it ends, and shows one only after it has a user prompt.
- A sweep deletes any session quiet longer than its idle limit (7 days by default), whatever its phase.

The user approved adopting all three rules on 2026-11-25.

## Decision

The island lists a session according to these rules, checked in order:

1. **Waiting for the user:** a session with a question, an approval, or a retained request notice is always listed. This
   keeps 0030's rule that a request is never covered. The reference's sweep would also delete such sessions.
2. **Ended:** an ended session leaves the list at once.
3. **No prompt yet:** an idle or unknown session that has never had an accepted prompt is not listed. The accepted submit
   marks a prompt, not its preview text, so an image-only or empty preview does not hide a session. A session seen
   working or with a response ready is listed even without a submit, because Bunlet may have joined mid-turn.
4. **Quiet:** any other session leaves once it has been quiet longer than the clean-up limit, in any state. The limit
   keeps its choices and its 7-day default; the setting is renamed **Clear quiet sessions after**. A session with no
   receipt time is never aged out.

Session tracking, sounds and request handling are unchanged. A hidden session returns to the list when it qualifies
again, for example after its next prompt.

## Consequences

Sessions seen only at start-up no longer add rows, and old Unknown rows clear themselves. An ended session is no longer
visible as Ended in the list. A session that Bunlet joined mid-turn disappears once it falls idle, until its next
prompt. Unit tests cover each rule. The behavior has not been checked on screen.
