import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.configuration 2.0 as PlasmaConfig

Kirigami.FormLayout {
    id: root


    RowLayout {
        Kirigami.FormData.label: qsTr("Hintamarginaali (snt/kWh)")

        TextField {
            id: marginInput
            width: 60
            placeholderText: "0,49"
            text: plasmoid.configuration.priceMargin !== undefined
            ? plasmoid.configuration.priceMargin.toFixed(2).replace(".", ",")
            : "0,49"

            onEditingFinished: {
                // Korvaa pilkku pisteeksi parseFloatia varten
                var val = parseFloat(text.replace(",", "."))
                if (!isNaN(val) && val >= 0 && val < 5) {
                    plasmoid.configuration.priceMargin = val
                    // Päivitä tekstikenttä suomalaiseen muotoon
                    text = val.toFixed(2).replace(".", ",")
                } else {
                    // Palautetaan vanha arvo, jos syöte virheellinen
                    text = plasmoid.configuration.priceMargin.toFixed(2).replace(".", ",")
                }
            }
        }
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true
        }
    }


    // -------------------------
    // Taustaväri
    // -------------------------
    RowLayout {
        Kirigami.FormData.label: "Taustaväri"

        Rectangle {
            id: bgColorPreview
            width: 32; height: 32
            radius: 4
            color: plasmoid.configuration.bgColor || "#1E1E1E"
            border.width: 1
            border.color: "#666"

            MouseArea {
                anchors.fill: parent
                onClicked: bgColorDialog.open()
            }
        }

        ColorDialog {
            id: bgColorDialog
            title: "Select background color"
            selectedColor: plasmoid.configuration.bgColor || "#1E1E1E"

            onAccepted: {
                plasmoid.configuration.bgColor = selectedColor
                bgColorPreview.color = selectedColor
            }
        }
    }

    // -------------------------
    // Otsikon väri
    // -------------------------
    RowLayout {
        Kirigami.FormData.label: "Otsikon väri"

        Rectangle {
            width: 32; height: 32
            radius: 4
            color: plasmoid.configuration.headerColor || "#FFD966"
            border.width: 1
            border.color: "#666"

            MouseArea {
                anchors.fill: parent
                onClicked: headerColorDialog.open()
            }
        }

        ColorDialog {
            id: headerColorDialog
            title: "Select header color"
            selectedColor: plasmoid.configuration.headerColor || "#FFD966"
            onAccepted: plasmoid.configuration.headerColor = selectedColor
        }
    }

    // -------------------------
    // Background opacity
    // -------------------------
    /* Slider {
        Kirigami.FormData.label: "Background opacity"
        from: 0.0
        to: 1.0
        stepSize: 0.01

        // välimuuttuja
        property real sliderValue: plasmoid.configuration.bgOpacity !== undefined ? plasmoid.configuration.bgOpacity : 1
        value: sliderValue

        onValueChanged: {
            sliderValue: value
            plasmoid.configuration.bgOpacity = value
        }
    } */

    // -------------------------
    // Hintojen värit
    // -------------------------
    RowLayout {
        Kirigami.FormData.label: "Korkean hinnan väri"

        Rectangle {
            width: 32; height: 32
            radius: 4
            color: plasmoid.configuration.highColor || "#FF4C4C"
            border.width: 1
            border.color: "#666"

            MouseArea {
                anchors.fill: parent
                onClicked: highColorDialog.open()
            }
        }

        ColorDialog {
            id: highColorDialog
            title: "Valitse korkean hinnan väri"
            selectedColor: plasmoid.configuration.highColor || "#FF4C4C"
            onAccepted: plasmoid.configuration.highColor = selectedColor
        }
    }

    RowLayout {
        Kirigami.FormData.label: "Normaalin hinnan väri"

        Rectangle {
            width: 32; height: 32
            radius: 4
            color: plasmoid.configuration.mediumColor || "#4CA6FF"
            border.width: 1
            border.color: "#666"

            MouseArea {
                anchors.fill: parent
                onClicked: mediumColorDialog.open()
            }
        }

        ColorDialog {
            id: mediumColorDialog
            title: "Valitse normaalin hinnan väri"
            selectedColor: plasmoid.configuration.mediumColor || "#4CA6FF"
            onAccepted: plasmoid.configuration.mediumColor = selectedColor
        }
    }

    RowLayout {
        Kirigami.FormData.label: "Halvan hinnan väri"

        Rectangle {
            width: 32; height: 32
            radius: 4
            color: plasmoid.configuration.lowColor || "#7CFF4C"
            border.width: 1
            border.color: "#666"

            MouseArea {
                anchors.fill: parent
                onClicked: lowColorDialog.open()
            }
        }

        ColorDialog {
            id: lowColorDialog
            title: "Valitse halvan hinnan väri"
            selectedColor: plasmoid.configuration.lowColor || "#7CFF4C"
            onAccepted: plasmoid.configuration.lowColor = selectedColor
        }
    }

    // -------------------------
    // Thresholds
    // -------------------------
    SpinBox {
        Kirigami.FormData.label: "Halvan hinnan raja (snt/kWh)"
        from: 0
        to: 100
        value: plasmoid.configuration.lowThreshold || 8
        onValueChanged: plasmoid.configuration.lowThreshold = value
    }

    SpinBox {
        Kirigami.FormData.label: "Korkean hinnan raja (snt/kWh)"
        from: 0
        to: 100
        value: plasmoid.configuration.highThreshold || 20
        onValueChanged: plasmoid.configuration.highThreshold = value
    }


    /* RowLayout {
        Kirigami.FormData.label: "Shadow color"

        Rectangle {
            width: 32; height: 32
            radius: 4
            color: plasmoid.configuration.shadowColor || "#000000"
            border.width: 1
            border.color: "#666"

            MouseArea {
                anchors.fill: parent
                onClicked: shadowColorDialog.open()
            }
        }

        ColorDialog {
            id: shadowColorDialog
            title: "Select shadow color"
            selectedColor: plasmoid.configuration.shadowColor || "#000000"
            onAccepted: plasmoid.configuration.shadowColor = selectedColor
        }
    } */
}
