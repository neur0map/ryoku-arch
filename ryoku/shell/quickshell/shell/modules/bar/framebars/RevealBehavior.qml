import QtQuick

// Shared reveal/slide interrupt behavior for the frame's bars, spacers, side
// menus and diagonal corner menus. A Behavior retarget animates from the
// CURRENT value to the new target over the full duration -- exactly what the
// two reveal forms need on interrupt: the slide reverses
// from the current position (contract 02 sec 5, contract 05 sec 5) and the
// diagonal grow restarts a fresh ease from the current position toward the
// new target (contract 01 sec 5). Neither snaps back to 0 to replay, so the one
// Behavior construct covers both; a proportional-reversal construct would
// diverge from the source. Callers pass duration and curve from Motion, so the
// reduce->0 collapse carries through and a duration of 0 becomes an instant cut.
Behavior {
    id: reveal
    property int duration: 0
    property int curve: Easing.Linear
    NumberAnimation { duration: reveal.duration; easing.type: reveal.curve }
}
