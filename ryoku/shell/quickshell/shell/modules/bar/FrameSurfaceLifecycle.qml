import QtQuick

QtObject {
    required property var keyring
    required property var polkit
    signal focusRestored()

    function handleClosed(id, context) {
        // Dismissing an authentication island IS an answer: polkitd blocks the
        // action until the agent replies, so a close that did not cancel would
        // leave the caller hanging on a prompt nobody can see any more.
        if (id === "polkit") {
            if (polkit.active && !polkit.busy) {
                polkit.cancel();
                focusRestored();
            }
            return;
        }
        if (id !== "keyring" || !context || context.promptId !== keyring.promptId || !keyring.active || keyring.busy) return;
        keyring.dismiss();
        focusRestored();
    }
}
