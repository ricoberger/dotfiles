# Atlassian Document Format (ADF) for Jira

`acli` accepts a Jira description as ADF (a JSON document), which renders with
real headings, paragraphs, and bullet lists in the Jira web UI. Plain Markdown
passed to `--description-file` is stored verbatim and looks broken in the UI, so
tickets created through `acli` must use ADF.

## Creation strategy: `--from-json`

Build one JSON file that contains the whole work item — `projectKey`, `type`,
`summary`, and the ADF `description` — and create it with:

```bash
acli jira workitem create --from-json /tmp/jira-workitem.json
```

Putting the summary inside the JSON file (instead of an inline `--summary` flag)
avoids broken shell commands when the title or description contains double
quotes, apostrophes, backticks, or other shell-special characters. No escaping
is needed — JSON string rules handle everything.

## File structure

```json
{
  "projectKey": "CORE",
  "type": "Task",
  "summary": "Concise ticket title",
  "description": {
    "version": 1,
    "type": "doc",
    "content": [
      {
        "type": "heading",
        "attrs": { "level": 3 },
        "content": [{ "type": "text", "text": "User Story" }]
      },
      {
        "type": "paragraph",
        "content": [
          {
            "type": "text",
            "text": "As a logged-in user, I want to reset my password, so that I can regain access without contacting support."
          }
        ]
      },
      {
        "type": "heading",
        "attrs": { "level": 3 },
        "content": [{ "type": "text", "text": "Background" }]
      },
      {
        "type": "paragraph",
        "content": [
          {
            "type": "text",
            "text": "Password reset is currently manual and creates avoidable support load."
          }
        ]
      },
      {
        "type": "heading",
        "attrs": { "level": 3 },
        "content": [{ "type": "text", "text": "Acceptance Criteria" }]
      },
      {
        "type": "bulletList",
        "content": [
          {
            "type": "listItem",
            "content": [
              {
                "type": "paragraph",
                "content": [
                  {
                    "type": "text",
                    "text": "User can request a reset link from the login page."
                  }
                ]
              }
            ]
          },
          {
            "type": "listItem",
            "content": [
              {
                "type": "paragraph",
                "content": [
                  {
                    "type": "text",
                    "text": "Reset link expires after a set period."
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
```

## Node rules

- The `description` value is always an ADF document:
  `{ "version": 1, "type": "doc", "content": [ ... ] }`.
- **Section labels** (`User Story`, `Background`, `Acceptance Criteria`) are
  `heading` nodes with `attrs.level` of `3`.
- **Paragraphs** are `paragraph` nodes wrapping one or more `text` nodes.
- **Acceptance criteria** is a single `bulletList`. Each criterion is a
  `listItem` containing one `paragraph` with a `text` node. Do not use
  `taskList`/checkboxes.
- **Emphasis** (optional) is added with marks on a `text` node, e.g.
  `"marks": [{ "type": "strong" }]` for bold. Keep it sparing.
- Do not repeat the title inside the description — the `summary` field is the
  Jira summary.
- Keep the section content identical to the Markdown ticket shown to the user;
  only the encoding changes.
