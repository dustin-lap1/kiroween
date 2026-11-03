---
inclusion: fileMatch
fileMatchPattern: ["skeleton/src/**", "apps/*/src/**", "**/index.html"]
---

# Frontend and styling

## Styling
- Tailwind CSS 4 utilities only; no CSS-in-JS, no component library.
- Colors come from theme tokens, never raw hex in components:
  `bg-surface` (page), `bg-panel` (cards), `border-edge`, `text-ink`,
  `text-muted`, `bg-accent` / `text-accent` / `text-accent-ink`, `font-display`.
- A new theme is one `[data-theme="<name>"]` block in `src/index.css`.
  Keep text contrast at WCAG AA (4.5:1 for body text) against `surface` and `panel`.
- Spooky is welcome (copy, icons, a subtle animation); readability first.
  Respect `prefers-reduced-motion` for any animation.

## Structure
- `src/App.jsx`: layout and page composition. `src/components/`: one component
  per file, PascalCase. `src/lib/`: non-UI code (the API client in `lib/api.js`).
- Call the backend only through `src/lib/api.js` with relative `/api/...` paths.
- Read app metadata from `app.config.json`; do not duplicate names or fields in code.

## Quality bar
- Semantic HTML: real `<button>`, `<label htmlFor>`, headings in order,
  `aria-label` on icon-only buttons, `role="alert"` for errors.
- Mobile first: works at 360 px wide; no horizontal scroll.
- Show loading, empty, and error states for every request.
- Run `npm run build` in the app folder after UI changes; fix every error.
