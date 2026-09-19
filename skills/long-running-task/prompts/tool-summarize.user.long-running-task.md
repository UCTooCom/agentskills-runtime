Summarize this tool execution result for a **long-horizon, multi-round task**.

This summary replaces the raw output for all later rounds. If you drop something here, the task
cannot recover it. So bias toward **completeness of task-relevant facts** over brevity.

## Non-negotiable: carry forward task state

Whenever the tool call/result touches any of the following, you MUST preserve it explicitly:

1. **Overall goal / acceptance criteria** — restate if the output references them.
2. **Artifacts**: exact file paths produced or read, plus whether each is *present, non-empty, and up to date*.
   Never paraphrase a path — copy it verbatim.
3. **Progress**: which planned steps are now done, and which are still pending.
4. **Failures / blockers**: error type, root cause, the exact resource that failed, and any retry/degradation
   already attempted (so the next round does not repeat it).
5. **Next action**: the single concrete next step, or the decision the agent must make.

## Extra: preserve the signals that cause long tasks to stall

Long tasks die from **burning the step budget on one stuck sub-task**. So also preserve:

- **Step budget**: how many ReAct steps this sub-task has consumed, and how many attempts were made
  with the *same* strategy. (Hard rule: same strategy fails twice → switch strategy, not parameters;
  four attempts without progress → report `blocked` and ask for a decision.)
- **Non-text carrier signals**: if the fetched page turned out to be an image / PDF / scan / iframe,
  say so explicitly, together with any direct image/PDF URL found. Plain-text extraction cannot work
  on these — the next round must switch to OCR / vision / a text-mirror source instead of re-fetching.
- **Exact failure strings**: copy error messages and status codes verbatim (e.g. TLS 10054, HTTP 403,
  timeout seconds). Paraphrased errors get re-diagnosed from scratch and waste steps.

## Tool Call:
{tool_call}

## Tool Result:
{tool_result}

---
Output the summary only, using this structure (omit a section only if it genuinely does not apply):

- **Status**: success / failure / partial
- **Artifacts**: `path` — present|missing, size/rows if known, freshness if known
- **Progress**: step N of M done — <one line>; still pending: <one line>
- **Blockers**: <error type / cause / affected resource / already tried>
- **Key Data**: ids, counts, timestamps needed by later rounds
- **Next**: <the concrete next action>
