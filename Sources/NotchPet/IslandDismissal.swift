/// When the open island closes without a direct command. Escape, the toggle shortcut and clicking the pill are separate.
enum IslandDismissal {
    /// Any press outside the island's shape closes it, whatever the hover setting, and also while typing.
    /// Unsent reply text stays in its draft.
    static func closesOnPress(expanded: Bool, pressInsideIsland: Bool) -> Bool {
        expanded && !pressInsideIsland
    }

    /// The pointer outside the island closes it when the setting is on, unless a text field is being edited.
    /// Keyboard focus without a text field does not count as typing.
    static func closesOnLeave(expanded: Bool, pointerInside: Bool, editingText: Bool, collapseOnLeave: Bool) -> Bool {
        expanded && !pointerInside && !editingText && collapseOnLeave
    }
}
