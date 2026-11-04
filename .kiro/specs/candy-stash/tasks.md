# Tasks: Candy Stash

- [x] 1. Define `candy` and `visitors` in `apps/candy-stash/app.config.json`
  (replace the sample `notes`)
  - Verify: the JSON parses, and `parseCollections` accepts it (node one-liner)
  - _Requirements: 1.1, 1.2, 2.1_
- [x] 2. Number constraints (`integer`, `min`, `max`) in
  `apps/candy-stash/api/lib/collections.mjs`
  - Verify: `validateItem` passes a valid candy and visitor group; rejects
    quantity 0, 2.5, "3", a missing quantity, a bad kind, a 61-character name,
    and an unknown field with `validation_failed`
  - _Requirements: 1.3, 1.4, 2.2, 2.3_
- [x] 3. `GET /api/stats`: `api/lib/stats.mjs` (pure), `stats` route in
  `matchRoute`, paginated Query per collection in `api/handler.mjs`
  - Verify: `matchRoute('/api/stats')` is `stats`; `sumField` sums and ignores
    bad values; `node --check` on the handler
  - _Requirements: 3.1, 3.2, 3.5, 4.4_
- [x] 4. `stats()` in `src/lib/api.js` and `src/components/StashTotals.jsx`
  with loading and error states
  - _Requirements: 3.1, 3.4, 4.1_
- [x] 5. `CollectionPanel.jsx`: `onChange` after create/delete, list loading
  state, number `min`/`max`/`step`, collection-scoped field ids; wire it in
  `App.jsx`
  - _Requirements: 1.5, 1.6, 2.4, 3.3, 4.2_
- [x] 6. `npm run build` in `apps/candy-stash`; fix every error
  - _Requirements: 4.3_
- [x] 7. No infrastructure changes (`apps/candy-stash/infra/` stays the skeleton's)
- [x] 8. `Plan-App.ps1 -Name candy-stash`, show the impact summary, wait for
  the human's explicit "yes", then `Apply-App.ps1 -Name candy-stash`
  - _Requirements: 5.1_
- [x] 9. `Publish-App.ps1 -Name candy-stash`; check `/api/health`, create one
  candy and list it through `<site_url>/api/candy`, check `/api/stats`;
  report the site URL
  - _Requirements: 5.2, 5.3_
