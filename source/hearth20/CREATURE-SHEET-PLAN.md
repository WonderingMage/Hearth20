# Deferred creature/token sheets

User request: replace Table → Help with a DM-only **Token Sheet** placeholder displaying **In development**. That placeholder is the only creature-sheet functionality authorized for this update.

For a later implementation:

- The DM needs a local sheet for the creature/token currently selected or controlled. Creature sheets should not require D&D Beyond.
- The user proposed a `.heart20creature` import containing appearance and sheet values. Keep this spelling as the user's provisional proposal; settle the final extension/schema when implementation starts.
- Values should be editable during the campaign. Example: a creature at 45 HP takes 20 damage and ends at 25 HP. Appearance, sheet values and midgame edits should persist with its campaign token.
- Preserve token identity and control grants, and keep GM-only creature records private. Design file validation, damage/healing rules and permissions during that later feature, not in this placeholder update.

Do not add import buttons, parsers, character/stat-block mechanics or health controls until the user requests the next phase.
