# 0020: Start fresh installs with Notch and Agents

- Status: accepted
- Date: 2026-11-06

## Context

A fresh install turned on Pet only. This came from [0013](0013-separate-standalone-pet-scope.md) ("Start with pet setup")
and the [feature-management spec](../specs/settings/feature-management.md).
The user expects `scripts/run.sh` and a fresh install to show the Notch, with Pet installed later from Settings.
Notch without Agents only shows "Agents is not installed."

## Options

- **Pet only (current):** suits people without coding agents. Hides the main agent features until the person finds Settings.
- **Notch only:** shows the island, but it has nothing to show until Agents is installed too.
- **Notch and Agents:** the island and its session controls are ready on first launch. Pet stays one Install action away.

## Decision

A fresh install turns on Notch and Agents. Pet starts uninstalled and is installed from Settings → Features.

## Reasoning

The user wants the Notch installed and launched by default, and Pet installable from Settings.
The user chose Agents with Notch, because Notch alone has nothing to show.

## Consequences

- Installing Agents still edits no provider configuration. Connect stays an explicit action under its own contract.
- A saved feature choice is kept. The new default applies only when no choice is stored.
- The legacy `agentMonitoringEnabled` opt-in migration is unchanged.
- Pet-only use stays supported. Removing Notch and Agents and installing Pet still gives the 0013 pet-only behavior.
- This replaces only 0013's pet-first setup. 0013's one app with an independent pet module still holds.
