# Requirements: Ghost Guestbook

## Introduction
Ghost Guestbook is a public guestbook where visitors leave a message for the
spirits: their name, the message, and a mood (eerie, friendly, or restless).
Messages are listed newest first, and each one shows a ghost emoji that matches
its mood. It is built from the Skeleton Crew skeleton in `apps/ghost-guestbook/`
with the ghost theme, in its own AWS account.

## Requirement 1: Leave a message
**User story:** As a visitor, I want to sign the guestbook with my name, a
message, and a mood, so that the spirits (and other visitors) can read it.
1. The UI SHALL show a form with a name field (required, at most 60
   characters), a message field (required, at most 500 characters), and a mood
   choice (required, one of eerie, friendly, restless).
2. WHEN the visitor submits a valid form THEN the system SHALL store the
   message with its creation time and SHALL show it at the top of the list
   without a page reload.
3. IF the name, message, or mood is missing, or the name or message is too
   long THEN the API SHALL reject the request with 400 and SHALL NOT store
   anything, and the UI SHALL show the reason in an alert.
4. IF the request contains a field other than name, message, or mood, or a mood
   outside the three options THEN the API SHALL reject it with 400.
5. WHILE a message is being saved the UI SHALL disable the submit button and
   show that it is saving.

## Requirement 2: Read the guestbook
**User story:** As a visitor, I want to read the latest messages newest first,
so that I see what the spirits heard most recently.
1. WHEN the page loads THEN the UI SHALL list the 50 newest messages, newest first.
2. Each message SHALL show the author's name, the message text (line breaks
   kept), the mood, and the date and time it was left.
3. WHILE the list is loading the UI SHALL show a loading state.
4. IF there are no messages THEN the UI SHALL show an empty state.
5. IF loading fails THEN the UI SHALL show the error in an alert.

## Requirement 3: Mood ghosts
**User story:** As a visitor, I want each message to show a ghost that matches
its mood, so that the guestbook feels haunted at a glance.
1. Each message SHALL show an emoji for its mood: eerie 👻, friendly 😊👻,
   restless 🌀👻.
2. IF a message has no mood or an unknown mood THEN the UI SHALL show a plain 👻.
3. The emoji SHALL have an accessible name that states the mood (for example
   "Mood: eerie"), so screen readers do not read the raw emoji.
4. The mood choice in the form SHALL show the same emoji next to each option.

## Requirement 4: Look and quality
1. The UI SHALL use the ghost theme from `app.config.json` and semantic color
   tokens only.
2. The UI SHALL work at 360 px wide with no horizontal scroll.
3. Any animation SHALL respect `prefers-reduced-motion`.

## Requirement 5: Deploy and operate like every skeleton app
1. The app SHALL be deployed only through `Plan-App.ps1`, the human's explicit
   yes, `Apply-App.ps1`, and `Publish-App.ps1`.
2. WHEN the app is deployed THEN `<site_url>/api/health` SHALL return `ok: true`
   and a create plus list through `<site_url>/api/entries` SHALL work.
3. The app SHALL keep the skeleton's guardrails: validated API, throttled
   stage, no request bodies in logs, error alarm, and monthly budget.
