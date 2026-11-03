# Tasks: Ghost Guestbook

- [x] 1. Define the `entries` collection in `apps/ghost-guestbook/app.config.json`
  (replace the sample `notes`; author, message, mood with `icons`)
  - Verify: the JSON parses, and `parseCollections` accepts it (node one-liner)
  - _Requirements: 1.1, 1.4, 3.1_
- [x] 2. Confirm the API needs no change: run `validateItem` locally against a
  valid entry, a missing mood, a bad mood, an unknown field, and a 61-character name
  - Verify: valid passes; the others throw `validation_failed`
  - _Requirements: 1.3, 1.4, 2.1_
- [x] 3. Mood emoji in `src/components/CollectionPanel.jsx`: icon before the
  title with an accessible name, fallback 👻, emoji in the select options,
  `motion-safe` float
  - _Requirements: 3.1 to 3.4, 4.3_
- [x] 4. Loading state for the list in `CollectionPanel.jsx`
  - _Requirements: 2.3 to 2.5_
- [x] 5. `npm run build` in `apps/ghost-guestbook`; fix every error
  - _Requirements: 4.1, 4.2_
- [x] 6. No infrastructure changes (`apps/ghost-guestbook/infra/` stays the skeleton's)
- [x] 7. `Plan-App.ps1 -Name ghost-guestbook`, show the impact summary, wait
  for the human's explicit "yes", then `Apply-App.ps1 -Name ghost-guestbook`
  - _Requirements: 5.1_
- [x] 8. `Publish-App.ps1 -Name ghost-guestbook`; check `/api/health`, create
  one entry and list it through `<site_url>/api/entries`; report the site URL
  - _Requirements: 5.2, 5.3_
