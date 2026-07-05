---
name: jira-create-ticket
description:
  This skill should be used when the user wants to write, create, or generate a
  Jira ticket. It produces well-structured tickets with a user story, background
  paragraph, and acceptance criteria checklist — shown as Markdown and created
  in Jira via Atlassian Document Format (ADF) so they render cleanly in the web
  UI.
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
     1. Read `references/adf-format.md` to load the ADF structure and the
        `--from-json` creation strategy.
     2. Write a single work item JSON file (e.g. `/tmp/jira-workitem.json`)
        containing `projectKey`, `type`, `summary`, and an ADF `description`.
        Convert the User Story, Background, and Acceptance Criteria sections
        into ADF nodes (headings, paragraphs, and a bullet list) — never include
        the title in the description, since it is the `summary`. Passing the
        whole work item via a JSON file (instead of inline
        `--summary`/`--description` flags) avoids broken commands when the title
        or description contains double quotes, apostrophes, backticks, or other
        shell-special characters, and ADF ensures the ticket renders cleanly in
        the Jira web UI.
     3. Create the ticket using `--from-json`:
        ```bash
        acli jira workitem create --from-json /tmp/jira-workitem.json
        ```
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
- The ticket shown to the user is Markdown only — no explanations or commentary
  around it unless the user asks. When creating the ticket in Jira, the same
  content is encoded as ADF (see `references/adf-format.md`); the wording stays
  identical, only the format changes.
