# Requirements: Candy Stash

Candy Stash is a trick-or-treat tracker. On Halloween night a household logs
the candy it hands out (or hauls in) and the groups of trick-or-treaters who
knock, and sees the running totals at the top of the page.

Built from the Skeleton Crew skeleton (`apps/candy-stash/`, pumpkin theme).

## Requirement 1: Track candy

**User story:** As a candy keeper, I want to record each kind of candy and how
many pieces I have, so I know what is in the stash.

1. WHEN the user submits the candy form with a name, kind, and quantity, THE
   system SHALL store the candy and show it at the top of the candy list.
2. THE system SHALL accept only `chocolate`, `gummy`, `sour`, or `hard` as the
   kind.
3. IF the quantity is missing, not a whole number, or less than 1, THEN THE API
   SHALL reject the request with `400 validation_failed` naming the `quantity`
   field.
4. IF the name is missing or longer than 60 characters, THEN THE API SHALL
   reject the request with `400 validation_failed` naming the `name` field.
5. WHERE the user ticks "Nut free", THE system SHALL store `nutFree: true` and
   show "Nut free: Yes" on the candy.
6. WHEN the user deletes a candy, THE system SHALL remove it from the list.

## Requirement 2: Track visitors

**User story:** As the person at the door, I want to log each group of
trick-or-treaters by costume and size, so I know how many came by.

1. WHEN the user submits the visitor form with a costume and group size, THE
   system SHALL store the visitor group and show it at the top of the list.
2. IF the group size is missing, not a whole number, or less than 1, THEN THE
   API SHALL reject the request with `400 validation_failed` naming the
   `groupSize` field.
3. IF the costume is missing or longer than 80 characters, THEN THE API SHALL
   reject the request with `400 validation_failed` naming the `costume` field.
4. WHEN the user deletes a visitor group, THE system SHALL remove it from the list.

## Requirement 3: Totals at the top

**User story:** As the household, I want to see total pieces of candy and total
visitors at a glance, so I know when to ration.

1. THE page SHALL show "Pieces of candy" (the sum of every candy's `quantity`)
   and "Visitors" (the sum of every visitor group's `groupSize`) above the
   collection panels.
2. THE totals SHALL count every stored item, not only the newest 50 that the
   list endpoint returns.
3. WHEN the user adds or deletes a candy or a visitor group, THE page SHALL
   refresh the totals without a page reload.
4. WHILE the totals are loading, THE page SHALL show a loading state; IF the
   totals request fails, THEN THE page SHALL show an error with `role="alert"`.
5. WHEN a client calls `GET /api/stats`, THE API SHALL return
   `{ "candyPieces": <number>, "visitors": <number>, "candyItems": <number>, "visitorGroups": <number> }`.

## Requirement 4: Quality bar

1. THE UI SHALL use the pumpkin theme tokens only (no raw colors) and work at
   360 px wide without horizontal scrolling.
2. THE lists SHALL show loading, empty, and error states.
3. THE app SHALL build with `npm run build` without errors.
4. THE API SHALL never use a DynamoDB Scan in a request path.

## Requirement 5: Ship it the standard way

1. THE infrastructure SHALL be created only through `Plan-App.ps1`, the
   human's explicit "yes", and `Apply-App.ps1`.
2. WHEN `Publish-App.ps1` finishes, `<site_url>/api/health` SHALL return `"ok":true`.
3. WHEN one candy is created through `<site_url>/api/candy`, THE list and
   `GET /api/stats` SHALL include it.
