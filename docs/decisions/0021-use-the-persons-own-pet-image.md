# 0021: Use the person's own image as the pet, with no built-in pet

- Status: accepted
- Date: 2026-11-06

## Context

Installing Pet showed a built-in white lionhead rabbit (`Sources/Pet/Resources`).
Custom images were available through Animate PNG, Import Sprite Sheet and Import Pet Pack in Pet settings.
The [pet workflow contract](../contracts/pet-workflows.md) used the built-in pet as the fallback for missing or invalid assets.
The user does not want the rabbit as the default pet.

## Options

- **Built-in rabbit by default (current):** a pet appears at once. Custom images are a later, optional step.
- **Ask on install: upload an image or use the rabbit:** no empty state. Keeps the rabbit in the app.
- **Upload only, no built-in pet:** every pet is the person's own. Pet is empty until an image is imported.

## Decision

Bunlet ships no built-in pet. Pet shows the person's imported image only.
Until an image is imported, Pet shows a prompt to choose one instead of a pet.

## Reasoning

The user chose upload only: "just don't even have the rabbit. get them to upload their own image."

## Consequences

- Installing Pet leads to the existing import actions. A pet appears only after an import succeeds.
- Missing or invalid saved assets show recovery instead of a built-in fallback. The saved selection is kept, as before.
- "Use Built-in Pet" is removed, and the rabbit artwork is no longer bundled.
- The [built-in pet spec](../specs/pets/built-in-pet.md) is replaced by this decision. Its historical tasks keep their original meaning.
- The Notch header uses the system `hare.fill` symbol for now. That is an app icon, not a pet.
