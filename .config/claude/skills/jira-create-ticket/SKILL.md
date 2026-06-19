---
name: jira-create-ticket
description:
  This skill should be used when the user wants to write, create, or generate a
  Jira ticket. It produces well-structured tickets in Markdown with a user
  story, background paragraph, and acceptance criteria checklist — ready to
  paste directly into Jira.
---

# Jira Create Ticket

## Overview

To generate a Jira ticket, take the information provided by the user and produce
a complete, paste-ready Markdown ticket following the standard format: a user
story opening line, a background paragraph, and a checklist of acceptance
criteria.

## Workflow

1. Read `references/ticket-template.md` to load the ticket structure and writing
   rules.
2. Gather the required information from the user's input:
   - **Who** is the persona (user role)?
   - **What** is the goal or feature?
   - **Why** does it matter (business/user value)?
   - **What conditions** must be met for the ticket to be closed?
3. Fill in the template. If any of the above is missing or ambiguous, infer
   reasonable defaults from context — do not ask clarifying questions unless the
   request is too vague to produce a useful ticket.
4. Output the completed ticket as a Markdown code block so the user can copy and
   paste it directly into Jira.
5. Ask the user if the ticket should be automatically created in Jira using the
   `acli` in the `CORE` project or if the ticket should be adjusted.
   - If the user wants to create the ticket automatically, ask for the ticket
     type, which can be "Epic", "Story", "Bug", or "Task". Then:
     1. Write the ticket description to a temporary file (e.g.
        `/tmp/jira-description.md`). Passing the description via a file instead
        of an inline `--description` flag avoids broken commands when the
        description contains double quotes, apostrophes, backticks, or other
        shell-special characters. Write only the User Story, Background, and
        Acceptance Criteria sections to this file — never the title, which is
        passed separately as the summary.
     2. Create the ticket using `--description-file`:
        ```bash
        acli jira workitem create \
          --project CORE \
          --type "<ticket-type>" \
          --summary "<ticket-title>" \
          --description-file /tmp/jira-description.md
        ```
        Replace `<ticket-type>` and `<ticket-title>` with the appropriate values
        from the generated ticket. `<ticket-title>` is the ticket's **Title**
        field, which becomes the Jira summary and is never repeated in the
        description file. Keep the title free of double quotes; if a
        title must contain them, write it into the file as well and use
        `--from-file` (first line = summary, remaining lines = description)
        instead of `--summary`/`--description-file`.
   - If the user wants to adjust the ticket, always output the full updated
     ticket in Markdown again and ask if they want to create it in Jira.

## Writing Principles

- Short and precise — no filler, no padding.
- User story: one tight line.
  `As a <persona>, I want to <goal>, so that <benefit>.`
- Background: 1–2 sentences max. Explain _why_, not _what_. Do not restate the
  user story.
- Acceptance criteria: short, precise action items. Present tense. No vague
  terms. No numbered/counted items (e.g. avoid "at least 3", "2 retries"). No
  `[]` checkboxes.
- A ticket title is always suggested as the first line of the ticket
  (`**Title:** ...`). It becomes the Jira summary and is not duplicated in the
  description.
- Output is Markdown only — no explanations or commentary around the ticket
  unless the user asks.
