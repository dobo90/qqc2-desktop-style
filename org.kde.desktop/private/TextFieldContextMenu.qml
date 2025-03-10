/*
    SPDX-FileCopyrightText: 2020 Devin Lin <espidev@gmail.com>
    SPDX-FileCopyrightText: 2021 Carl Schwan <carlschwan@kde.org>

    SPDX-License-Identifier: LGPL-2.0-or-later
*/

pragma Singleton

import QtQuick
import QtQml
import QtQuick.Controls
import org.kde.kirigami 2.5 as Kirigami

Menu {
    id: contextMenu

    property Item target
    property bool deselectWhenMenuClosed: true
    property int restoredCursorPosition: 0
    property int restoredSelectionStart
    property int restoredSelectionEnd
    property bool persistentSelectionSetting
    property var spellcheckhighlighter: null
    property var spellcheckhighlighterLoader: null
    property var suggestions: []
    Component.onCompleted: persistentSelectionSetting = persistentSelectionSetting // break binding

    property var runOnMenuClose: () => {}

    parent: Overlay.overlay

    function storeCursorAndSelection() {
        contextMenu.restoredCursorPosition = target.cursorPosition;
        contextMenu.restoredSelectionStart = target.selectionStart;
        contextMenu.restoredSelectionEnd = target.selectionEnd;
    }

    // target is pressed with mouse
    function targetClick(handlerPoint, newTarget, spellcheckhighlighter, mousePosition) {
        if (handlerPoint.pressedButtons === Qt.RightButton) { // only accept just right click
            if (contextMenu.visible) {
                deselectWhenMenuClosed = false; // don't deselect text if menu closed by right click on textfield
                dismiss();
            } else {
                contextMenu.target = newTarget;
                contextMenu.target.persistentSelection = true; // persist selection when menu is opened
                contextMenu.spellcheckhighlighterLoader = spellcheckhighlighter;
                if (spellcheckhighlighter && spellcheckhighlighter.active) {
                    contextMenu.spellcheckhighlighter = spellcheckhighlighter.item;
                    contextMenu.suggestions = mousePosition ? spellcheckhighlighter.item.suggestions(mousePosition) : [];
                } else {
                    contextMenu.spellcheckhighlighter = null;
                    contextMenu.suggestions = [];
                }
                storeCursorAndSelection();
                popup(contextMenu.target);
                // slightly locate context menu away from mouse so no item is selected when menu is opened
                x += 1
                y += 1
            }
        } else {
            dismiss();
        }
    }

    // context menu keyboard key
    function targetKeyPressed(event, newTarget) {
        if (event.modifiers === Qt.NoModifier && event.key === Qt.Key_Menu) {
            contextMenu.target = newTarget;
            target.persistentSelection = true; // persist selection when menu is opened
            storeCursorAndSelection();
            popup(contextMenu.target);
        }
    }

    readonly property bool targetIsPassword: target !== null && (target.echoMode === TextInput.PasswordEchoOnEdit || target.echoMode === TextInput.Password)

    onAboutToShow: {
        if (Overlay.overlay) {
            let tempZ = 0
            for (let i in Overlay.overlay.visibleChildren) {
                tempZ = Math.max(tempZ, Overlay.overlay.visibleChildren[i].z)
            }
            z = tempZ + 1
        }
    }

    // deal with whether or not text should be deselected
    onClosed: {
        // restore text field's original persistent selection setting
        target.persistentSelection = persistentSelectionSetting
        // deselect text field text if menu is closed not because of a right click on the text field
        if (deselectWhenMenuClosed) {
            target.deselect();
        }
        deselectWhenMenuClosed = true;

        // restore cursor position
        target.forceActiveFocus();
        target.cursorPosition = restoredCursorPosition;
        target.select(restoredSelectionStart, restoredSelectionEnd);

        // run action, and free memory
        runOnMenuClose();
        runOnMenuClose = () => {};
    }

    onOpened: {
        runOnMenuClose = () => {};
    }

    Instantiator {
        active: target !== null && !target.readOnly && spellcheckhighlighter !== null && spellcheckhighlighter.active && spellcheckhighlighter.wordIsMisspelled
        model: suggestions
        delegate: MenuItem {
            text: modelData
            onClicked: {
                deselectWhenMenuClosed = false;
                runOnMenuClose = () => spellcheckhighlighter.replaceWord(modelData);
            }
        }
        onObjectAdded: {
            contextMenu.insertItem(0, object)
        }
        onObjectRemoved: contextMenu.removeItem(0)
    }

    MenuItem {
        visible: target !== null && !target.readOnly && spellcheckhighlighter !== null && spellcheckhighlighter.active && spellcheckhighlighter.wordIsMisspelled && suggestions.length === 0
        action: Action {
            text: spellcheckhighlighter ? qsTr("No suggestions for \"%1\"").arg(spellcheckhighlighter.wordUnderMouse) : ''
            enabled: false
        }
    }

    MenuItem {
        visible: target !== null && !target.readOnly && spellcheckhighlighter !== null && spellcheckhighlighter.active && spellcheckhighlighter.wordIsMisspelled
        action: Action {
            text: spellcheckhighlighter ? qsTr("Add \"%1\" to dictionary").arg(spellcheckhighlighter.wordUnderMouse) : ''
            onTriggered: {
                deselectWhenMenuClosed = false;
                runOnMenuClose = () => spellcheckhighlighter.addWordToDictionary(spellcheckhighlighter.wordUnderMouse);
            }
        }
    }

    MenuItem {
        visible: target !== null && !target.readOnly && spellcheckhighlighter !== null && spellcheckhighlighter.active && spellcheckhighlighter.wordIsMisspelled
        action: Action {
            text: qsTr("Ignore")
            onTriggered: {
                deselectWhenMenuClosed = false;
                runOnMenuClose = () => spellcheckhighlighter.ignoreWord(spellcheckhighlighter.wordUnderMouse);
            }
        }
    }

    MenuItem {
        visible: target !== null && !target.readOnly && spellcheckhighlighterLoader && spellcheckhighlighterLoader.activable
        checkable: true
        checked: spellcheckhighlighter ? spellcheckhighlighter.active : false
        text: qsTr("Enable Spellchecker")
        onCheckedChanged: {
            spellcheckhighlighterLoader.active = checked;
            spellcheckhighlighter = spellcheckhighlighterLoader.item;
        }
    }

    MenuSeparator {
        visible: target !== null && !target.readOnly && ((spellcheckhighlighter !== null && spellcheckhighlighter.active && spellcheckhighlighter.wordIsMisspelled) || (spellcheckhighlighterLoader && spellcheckhighlighterLoader.activable))
    }

    MenuItem {
        visible: target !== null && !target.readOnly && !targetIsPassword
        action: Action {
            icon.name: "edit-undo-symbolic"
            text: qsTr("Undo")
            shortcut: StandardKey.Undo
        }
        enabled: target !== null && target.canUndo
        onTriggered: {
            deselectWhenMenuClosed = false;
            runOnMenuClose = () => target.undo();
        }
    }
    MenuItem {
        visible: target !== null && !target.readOnly && !targetIsPassword
        action: Action {
            icon.name: "edit-redo-symbolic"
            text: qsTr("Redo")
            shortcut: StandardKey.Redo
        }
        enabled: target !== null && target.canRedo
        onTriggered: {
            deselectWhenMenuClosed = false;
            runOnMenuClose = () => target.redo();
        }
    }
    MenuSeparator {
        visible: target !== null && !target.readOnly && !targetIsPassword
    }
    MenuItem {
        visible: target !== null && !target.readOnly && !targetIsPassword
        action: Action {
            icon.name: "edit-cut-symbolic"
            text: qsTr("Cut")
            shortcut: StandardKey.Cut
        }
        enabled: target !== null && target.selectedText
        onTriggered: {
            deselectWhenMenuClosed = false;
            runOnMenuClose = () => target.cut();
        }
    }
    MenuItem {
        action: Action {
            icon.name: "edit-copy-symbolic"
            text: qsTr("Copy")
            shortcut: StandardKey.Copy
        }
        enabled: target !== null && target.selectedText
        visible: !targetIsPassword
        onTriggered: {
            deselectWhenMenuClosed = false;
            runOnMenuClose = () => target.copy();
        }
    }
    MenuItem {
        visible: target !== null && !target.readOnly
        action: Action {
            icon.name: "edit-paste-symbolic"
            text: qsTr("Paste")
            shortcut: StandardKey.Paste
        }
        enabled: target !== null && target.canPaste
        onTriggered: {
            deselectWhenMenuClosed = false;
            runOnMenuClose = () => target.paste();
        }
    }
    MenuItem {
        visible: target !== null && !target.readOnly
        action: Action {
            icon.name: "edit-delete-symbolic"
            text: qsTr("Delete")
            shortcut: StandardKey.Delete
        }
        enabled: target !== null && target.selectedText
        onTriggered: {
            deselectWhenMenuClosed = false;
            runOnMenuClose = () => target.remove(target.selectionStart, target.selectionEnd);
        }
    }
    MenuSeparator {
        visible: !targetIsPassword
    }
    MenuItem {
        action: Action {
            icon.name: "edit-select-all-symbolic"
            text: qsTr("Select All")
            shortcut: StandardKey.SelectAll
        }
        visible: !targetIsPassword
        onTriggered: {
            deselectWhenMenuClosed = false;
            runOnMenuClose = () => target.selectAll();
        }
    }
}
