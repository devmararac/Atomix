AtomiX 472 compatible MoveData resources.

Copy the contents of Moves/ into your project's res://Resources/Moves/ folder.
These resources use the exported fields found in your supplied MoveData.gd, DamageAction.gd, HealAction.gd, StatusAction.gd and MoveEffect.gd.

skill_id, element, slot, category and effect_name are stored as metadata because MoveData.gd currently does not export a skill_id field.
Status effects are limited to the ten enum values defined by your MoveEffect.gd.
