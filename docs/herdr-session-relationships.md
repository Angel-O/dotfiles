# Herdr launcher session relationship records

The launcher writes one private JSON file after a delegate has started and its
Herdr identity has been verified:

```text
$HOME/.local/state/herdr/session-relationships/<socket-partition>/<delegate-session-id>.json
```

`socket-partition` is the URI-encoded exact value of `HERDR_SOCKET_PATH`,
produced with jq as:

```sh
jq -rn --arg socket "$HERDR_SOCKET_PATH" '$socket | @uri'
```

This keeps records from separate Herdr servers apart. Files are direct
children of their partition directory; a consumer should inspect each `.json`
file independently. The directory and records are private (`0700` and
`0600`). Records persist without expiry.

Version 1 has exactly these fields:

```json
{
  "schemaVersion": 1,
  "orchestratorSessionID": "OpenCode session ID",
  "delegateSessionID": "OpenCode session ID",
  "delegateRole": "worker or architect",
  "launchName": "validated launcher name"
}
```

Both session IDs must match `^ses[A-Za-z0-9_-]+$`; the filename must be
`<delegateSessionID>.json`. `delegateRole` is `worker` or `architect`, and
`launchName` matches `^[a-z][a-z0-9_-]{0,31}$`. The name is a fallback label,
not an identity. Records contain no prompts, credentials, or tracking IDs.

Readers should accept only version 1 records with all fields and valid values,
and require the filename to match `delegateSessionID`. Ignore an invalid,
unreadable, or unknown-version record without suppressing other valid records
in the same partition.
