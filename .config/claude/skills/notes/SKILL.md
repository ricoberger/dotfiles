---
name: notes
description: |
  Add new notes to @/Users/ricoberger/Documents/GitHub/ricoberger/notes/daily.
---

# Notes

Add new notes to `@/Users/ricoberger/Documents/GitHub/ricoberger/notes/daily`.
The files in the directory are organized by date: `YYYY/MM/YYYY-MM-DD.md`, e.g.
`2026/05/2026-05-04.md`.

## Workflow

- If no note for the current date exists, create a new note using the template
  `@/Users/ricoberger/Documents/GitHub/ricoberger/notes/daily/template.md`
- Add the new note to the existing note for the current date, if it exists.
- The following formats are supported for the new note:
  - `- <note>`: Should be added to the `Notes` section of the note.
  - `- [ ] <note>`: Should be added to the `Tasks` section of the note.
  - `<note>`: Should be added to the `Schedule` section of the note, with the
    current time as `HH:MM`.
