# JIRA Ticket Template

## Structure

Every ticket follows this exact structure, in order:

---

**Title:** `<concise ticket title>`

---

**[User Story]**

As a `<persona>`, I want to `<goal>`, so that `<benefit>`.

---

**Background**

`<1–2 sentences explaining why this work matters>`

---

**Acceptance Criteria**

- `<criterion 1>`
- `<criterion 2>`
- `<criterion n>`

---

## Writing Rules

- **Title**: One concise line summarizing the work. Maps to the Jira summary
  (acli `--summary`). Do not duplicate it inside the description.
- **User story**: Fill in the three blanks with concrete, specific language.
  `persona` is a role (e.g. "logged-in user", "admin", "data analyst"). `goal`
  is an action. `benefit` is the business or user value.
- **Background**: One short paragraph. 1–2 sentences max. Explain why this work
  matters. Do not restate the user story or over-explain.
- **Acceptance criteria**: Bulleted checklist. Each item is a short, precise
  action item. Write in present tense ("User can...", "System returns...",
  "Email is sent..."). No vague terms like "works correctly" or "is fast". No
  numbered/counted items (e.g. avoid "at least 3 options" or "2 retries").
- **Tone**: Short, precise, no filler words. Omit phrases like "In order to" or
  "This ticket aims to".
- **Format**: Output in Markdown, ready to paste directly into JIRA.
