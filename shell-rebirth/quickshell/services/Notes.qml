pragma Singleton
import QtQuick
import QtCore
import Quickshell.Io
import qs.components

QtObject {
    id: root

    property var notes: []
    property var categories: ["notes"]
    property string currentCategory: "notes"
    property var categoryCommands: ({})
    property var categoryKeepOpen: ({})
    property bool sortDescending: true  // New property for sort order

    property Settings store: Settings {
        location: StandardPaths.standardLocations(StandardPaths.ConfigLocation)[0] + "/quickshell/notes.conf"
        category: "notes"
        property string data: "[]"
        property string categoriesData: "[\"notes\"]"
        property string currentCategoryData: "notes"
        property string categoryCommandsData: "{}"
        property string categoryKeepOpenData: "{}"
        property string sortDescendingData: "true"  // New store property
    }

    function load() {
        try {
            var loadedNotes = JSON.parse(store.data)
            // Ensure old notes without subtext are properly handled
            notes = loadedNotes.map(function(note) {
                if (note.subtext === undefined) {
                    note.subtext = ""
                }
                return note
            })
        } catch (e) {
            console.warn("Failed to load notes:", e)
            notes = []
        }

        try {
            var loadedCategories = JSON.parse(store.categoriesData)
            if (loadedCategories.indexOf("notes") === -1) {
                loadedCategories.unshift("notes")
            }
            categories = loadedCategories
        } catch (e) {
            console.warn("Failed to load categories:", e)
            categories = ["notes"]
        }

        try {
            var loadedCommands = JSON.parse(store.categoryCommandsData)
            categoryCommands = loadedCommands
        } catch (e) {
            console.warn("Failed to load category commands:", e)
            categoryCommands = {}
        }

        // Load keep-open settings
        try {
            var loadedKeepOpen = JSON.parse(store.categoryKeepOpenData)
            categoryKeepOpen = loadedKeepOpen
        } catch (e) {
            console.warn("Failed to load category keep-open settings:", e)
            categoryKeepOpen = {}
        }

        // Load sort order preference
        try {
            sortDescending = store.sortDescendingData === "true"
        } catch (e) {
            console.warn("Failed to load sort order:", e)
            sortDescending = true
        }

        currentCategory = store.currentCategoryData || "notes"
    }

    function save() {
        store.data = JSON.stringify(notes)
        store.categoriesData = JSON.stringify(categories)
        store.categoryCommandsData = JSON.stringify(categoryCommands)
        store.categoryKeepOpenData = JSON.stringify(categoryKeepOpen)
        store.sortDescendingData = sortDescending.toString()
        store.currentCategoryData = currentCategory
    }

    function add(text, category, subtext) {
        if (text.trim() === "") return
        var cat = category || currentCategory
        var newNotes = notes.slice()
        newNotes.unshift({
            id: Date.now() + Math.random(),
            text: text,
            subtext: subtext || "",
            time: Date.now(),
            category: cat
        })
        notes = newNotes
        save()
    }

    function updateNote(index, text, subtext, category) {
        if (index < 0 || index >= notes.length) return
        if (text.trim() === "") return

        var newNotes = notes.slice()
        // Manually copy properties instead of using spread operator
        var updatedNote = {
            id: newNotes[index].id,
            text: text,
            subtext: subtext || "",
            time: newNotes[index].time,
            category: category || newNotes[index].category
        }
        newNotes[index] = updatedNote
        notes = newNotes
        save()
    }

    function remove(index) {
        var newNotes = notes.slice()
        newNotes.splice(index, 1)
        notes = newNotes
        save()
    }

    function addCategory(categoryName) {
        if (categoryName.trim() === "") return
        if (categories.indexOf(categoryName) !== -1) return

        var newCategories = categories.slice()
        newCategories.push(categoryName)
        categories = newCategories

        // Initialize with no command and keep-open false
        var newCommands = JSON.parse(JSON.stringify(categoryCommands))
        newCommands[categoryName] = ""
        categoryCommands = newCommands

        var newKeepOpen = JSON.parse(JSON.stringify(categoryKeepOpen))
        newKeepOpen[categoryName] = false
        categoryKeepOpen = newKeepOpen

        save()
    }

    function copy(text) {
        console.log(text);
        copyProc.exec([`/usr/bin/wl-copy`, text])
    }

    function executeNote(note) {
        if (!note) return

        var command = categoryCommands[note.category] || ""
        var keepOpen = categoryKeepOpen[note.category] || false

        if (command.trim() === "") {
            var textToCopy = note.text
            if (note.subtext && note.subtext.trim() !== "") {
                textToCopy += "\n\n" + note.subtext
            }
            copy(textToCopy)
            return
        }

        var finalCommand = command.replace(/\$text/g, note.text)
            .replace(/\$note/g, note.text)

        var proc = Qt.createQmlObject(`
        import Quickshell.Io
        Process {}
    `, root)

        if (keepOpen) {
            // Keep terminal open after command finishes
            proc.exec(["kitty", "--hold", "-e", "sh", "-c", finalCommand])
        } else {
            // Run directly without a terminal — GUI apps won't get killed
            proc.exec(["sh", "-c", finalCommand + " &"])
        }
    }

    function removeCategory(categoryName) {
        if (categoryName === "notes") return // Cannot remove default category

        var newCategories = categories.slice()
        var index = newCategories.indexOf(categoryName)
        if (index !== -1) {
            newCategories.splice(index, 1)
            categories = newCategories

            // Remove category command
            var newCommands = JSON.parse(JSON.stringify(categoryCommands))
            delete newCommands[categoryName]
            categoryCommands = newCommands

            // Remove keep-open setting
            var newKeepOpen = JSON.parse(JSON.stringify(categoryKeepOpen))
            delete newKeepOpen[categoryName]
            categoryKeepOpen = newKeepOpen

            // Remove all notes in this category
            var newNotes = []
            for (var i = 0; i < notes.length; i++) {
                if (notes[i].category !== categoryName) {
                    newNotes.push(notes[i])
                }
            }
            notes = newNotes

            // Switch to default if current category was removed
            if (currentCategory === categoryName) {
                currentCategory = "notes"
            }

            save()
        }
    }

    function setCategoryCommand(categoryName, command) {
        if (!categoryName) return

        var newCommands = JSON.parse(JSON.stringify(categoryCommands))
        newCommands[categoryName] = command
        categoryCommands = newCommands
        save()
    }

    function setCategoryKeepOpen(categoryName, keepOpen) {
        if (!categoryName) return

        var newKeepOpen = JSON.parse(JSON.stringify(categoryKeepOpen))
        newKeepOpen[categoryName] = keepOpen
        categoryKeepOpen = newKeepOpen
        save()
    }

    function setCurrentCategory(categoryName) {
        currentCategory = categoryName
        save()
    }

    function toggleSortOrder() {
        sortDescending = !sortDescending
        save()
    }

    function getNotesForCategory(categoryName) {
        var filtered = []
        for (var i = 0; i < notes.length; i++) {
            if (notes[i].category === categoryName) {
                filtered.push(notes[i])
            }
        }

        // Return in current sort order (newest first by default)
        if (sortDescending) {
            return filtered
        } else {
            // Reverse the array to show oldest first
            var reversed = []
            for (var j = filtered.length - 1; j >= 0; j--) {
                reversed.push(filtered[j])
            }
            return reversed
        }
    }

    function findNoteIndex(noteId) {
        for (var i = 0; i < notes.length; i++) {
            if (notes[i].id === noteId) {
                return i
            }
        }
        return -1
    }

    property Process copyProc: Process {
        id: copyProc
    }

    property Process terminalProc: Process {
        id: terminalProc
    }

    Component.onCompleted: load()
}