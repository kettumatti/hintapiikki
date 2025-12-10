import QtQuick 6.5
import QtQuick.Layouts
import QtQuick.Controls 6.5
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: root
    implicitWidth: 600
    implicitHeight: childrenRect.height

    // Yleinen apufunktio fallbackille
    function getConfigValue(key, fallback) {
        const v = plasmoid && plasmoid.configuration ? plasmoid.configuration[key] : undefined;
        return (v === undefined || v === null || (typeof v === "number" && isNaN(v))) ? fallback : v;
    }

    Kirigami.FormLayout {
        anchors.fill: parent
        anchors.margins: 12

        // Hintamarginaali (snt/kWh)
        RowLayout {
            Kirigami.FormData.label: qsTr("Hintamarginaali (snt/kWh)")

            TextField {
                id: priceMargin
                width: 80
                placeholderText: "0,49"

                Component.onCompleted: {
                    // Ladataan tallennettu arvo tai oletus
                    const v = getConfigValue("priceMargin", 0.49);
                    text = Number(v).toFixed(2).replace(".", ",");
                }

                onEditingFinished: {
                    // Muutetaan pilkku pisteeksi parseFloatia varten
                    let parsed = parseFloat(text.replace(",", "."));

                    // Jos syöte on kelvollinen, tallennetaan ja muotoillaan takaisin pilkulla
                    if (!isNaN(parsed) && parsed >= 0 && parsed < 5) {
                        plasmoid.configuration.priceMargin = parsed;
                        text = parsed.toFixed(2).replace(".", ",");
                    } else {
                        // Virheellinen syöte -> palataan viimeksi tallennettuun arvoon tai oletukseen
                        const cur = getConfigValue("priceMargin", 0.49);
                        text = Number(cur).toFixed(2).replace(".", ",");
                    }
                }

                // Lisätty: syötteen validointi heti kirjoitettaessa (vain numerot + pilkku/piste)
                onTextChanged: {
                    // Salli vain numerot, pilkku tai piste
                    const sanitized = text.replace(/[^0-9.,]/g, "");
                    if (sanitized !== text) text = sanitized;
                }
            }
        }

        // Enter/Return ei sulje dialogia vahingossa
        Keys.onPressed: {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true;
            }
        }

        // Taustaväri
        RowLayout {
            Kirigami.FormData.label: qsTr("Taustaväri")
            Rectangle {
                id: bgColorPreview
                width: 32; height: 32
                radius: 4
                color: getConfigValue("bgColor", "#1E1E1E")
                border.width: 1; border.color: "#666"
                MouseArea { anchors.fill: parent; onClicked: bgColorDialog.open() }
            }
            ColorDialog {
                id: bgColorDialog
                title: qsTr("Valitse taustaväri")
                Component.onCompleted: selectedColor = getConfigValue("bgColor", "#1E1E1E");
                onAccepted: {
                    plasmoid.configuration.bgColor = selectedColor;
                    bgColorPreview.color = selectedColor;
                }
            }
        }

        // Otsikon väri
        RowLayout {
            Kirigami.FormData.label: qsTr("Otsikon väri")
            Rectangle {
                id: headerColorPreview
                width: 32; height: 32
                radius: 4
                color: getConfigValue("headerColor", "#FFD966")
                border.width: 1; border.color: "#666"
                MouseArea { anchors.fill: parent; onClicked: headerColorDialog.open() }
            }
            ColorDialog {
                id: headerColorDialog
                title: qsTr("Valitse otsikon väri")
                Component.onCompleted: selectedColor = getConfigValue("headerColor", "#FFD966");
                onAccepted: {
                    plasmoid.configuration.headerColor = selectedColor;
                    headerColorPreview.color = selectedColor;
                }
            }
        }

        // Korkean hinnan väri
        RowLayout {
            Kirigami.FormData.label: qsTr("Korkean hinnan väri")
            Rectangle {
                id: highColorPreview
                width: 32; height: 32
                radius: 4
                color: getConfigValue("highColor", "#FF4C4C")
                border.width: 1; border.color: "#666"
                MouseArea { anchors.fill: parent; onClicked: highColorDialog.open() }
            }
            ColorDialog {
                id: highColorDialog
                title: qsTr("Valitse korkean hinnan väri")
                Component.onCompleted: selectedColor = getConfigValue("highColor", "#FF4C4C");
                onAccepted: {
                    plasmoid.configuration.highColor = selectedColor;
                    highColorPreview.color = selectedColor;
                }
            }
        }

        // Normaalin hinnan väri
        RowLayout {
            Kirigami.FormData.label: qsTr("Normaalin hinnan väri")
            Rectangle {
                id: mediumColorPreview
                width: 32; height: 32
                radius: 4
                color: getConfigValue("mediumColor", "#4CA6FF")
                border.width: 1; border.color: "#666"
                MouseArea { anchors.fill: parent; onClicked: mediumColorDialog.open() }
            }
            ColorDialog {
                id: mediumColorDialog
                title: qsTr("Valitse normaalin hinnan väri")
                Component.onCompleted: selectedColor = getConfigValue("mediumColor", "#4CA6FF");
                onAccepted: {
                    plasmoid.configuration.mediumColor = selectedColor;
                    mediumColorPreview.color = selectedColor;
                }
            }
        }

        // Halvan hinnan väri
        RowLayout {
            Kirigami.FormData.label: qsTr("Halvan hinnan väri")
            Rectangle {
                id: lowColorPreview
                width: 32; height: 32
                radius: 4
                color: getConfigValue("lowColor", "#7CFF4C")
                border.width: 1; border.color: "#666"
                MouseArea { anchors.fill: parent; onClicked: lowColorDialog.open() }
            }
            ColorDialog {
                id: lowColorDialog
                title: qsTr("Valitse halvan hinnan väri")
                Component.onCompleted: selectedColor = getConfigValue("lowColor", "#7CFF4C");
                onAccepted: {
                    plasmoid.configuration.lowColor = selectedColor;
                    lowColorPreview.color = selectedColor;
                }
            }
        }

        // Thresholds
        SpinBox {
            id: lowThreshold
            Kirigami.FormData.label: "Halvan hinnan raja (snt/kWh)"
            from: 0; to: 100
            value: getConfigValue("lowThreshold", 8) ?? 8
            onValueChanged: plasmoid.configuration.lowThreshold = value
        }

        SpinBox {
            id: highThreshold
            Kirigami.FormData.label: "Korkean hinnan raja (snt/kWh)"
            from: 0; to: 100
            value: getConfigValue("highThreshold", 20) ?? 20
            onValueChanged: plasmoid.configuration.highThreshold = value
        }
        Switch {
            id: showQuarterly
            Kirigami.FormData.label: qsTr("15 min hintatiedot")
            checked: plasmoid.configuration.showQuarterly
            onToggled: plasmoid.configuration.showQuarterly = checked
        }
        
        ///// RESET ////
        Button {
            text: qsTr("Palauta oletukset")
            icon.name: "edit-undo"   // KDE:n oletusikoni
            onClicked: {
                // Palauta jokainen avain skeeman oletusarvoon
                plasmoid.configuration.priceMargin = 0.49
                plasmoid.configuration.bgColor = "#1E1E1E"
                plasmoid.configuration.headerColor = "#FFD966"
                plasmoid.configuration.highColor = "#FF4C4C"
                plasmoid.configuration.mediumColor = "#4CA6FF"
                plasmoid.configuration.lowColor = "#7CFF4C"
                plasmoid.configuration.lowThreshold = 8
                plasmoid.configuration.highThreshold = 20
                plasmoid.configuration.showQuarterly = false

                // Päivitä UI:n esikatselut
                priceMargin.text = "0,49"
                bgColorPreview.color = plasmoid.configuration.bgColor
                headerColorPreview.color = plasmoid.configuration.headerColor
                highColorPreview.color = plasmoid.configuration.highColor
                mediumColorPreview.color = plasmoid.configuration.mediumColor
                lowColorPreview.color = plasmoid.configuration.lowColor
                lowThreshold.value = plasmoid.configuration.lowThreshold
                highThreshold.value = plasmoid.configuration.highThreshold
                showQuarterly.checked = plasmoid.configuration.showQuarterly
            }
        }
    }
}
