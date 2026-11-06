# 0016: Use Bunlet as the app name

- Status: accepted
- Date: 2026-11-06

## Context

The README already uses Bunlet. The app still displays Notch Pet and builds `Notch Pet.app`.
The pet works on the desktop independently of the optional Notch and Agents features.

## Options

- **Bunlet:** emphasizes the pet, including desktop use.
- **Notchbun:** emphasizes the notch companion.
- **Notch Pet:** retains the existing app name and defers the rename.

## Decision

Use Bunlet for the visible product name and `Bunlet.app` for the app bundle.
Keep internal targets, executables, bundle identifiers, preferences, assets and integration ownership paths stable.

## Reasoning

The user chose Bunlet to emphasize the pet, including desktop use.
They approved a visible rename that preserves existing storage and integration identities.
A full internal rename would add migration work without changing the visible product.

## Consequences

App labels, packaging and CI bundle checks must agree with the README.
Installed hook commands can contain the old app path. Existing configuration is not rewritten automatically.
Moving to the new bundle path requires the existing Remove then Connect flow where setup detects a moved helper.
The repository name, mascot artwork and icon remain separate work.
See the [product-name spec](../specs/settings/product-name.md).
