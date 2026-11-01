Summarize the tool execution result.

Keep the summary self-sufficient for the agent's **next** decision — do not drop anything the agent would need to continue.

## Tool Call:
{tool_call}

## Tool Result:
{tool_result}

---
Output the summary only, in this structure (omit empty sections):

- **Status**: success / failure / partial
- **Key Data**: ids, paths, values, counts, timestamps that were returned
- **Progress**: what this step accomplished toward the overall goal (if identifiable)
- **Error**: error type, cause, affected resource (on failure)
- **Next**: the concrete next action this result implies or the agent had already stated
