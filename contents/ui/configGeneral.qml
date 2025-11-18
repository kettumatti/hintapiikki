import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
// import org.kde.kquickcontrolsaddons 2.0 as KQControls
import org.kde.kquickcontrols as KQControls
import org.kde.kquickcontrolsaddons
import org.kde.kcmutils as KCM




Kirigami.ScrollablePage {
    title: i18n("Yleiset asetukset")
    
    property alias cfg_priceMargin: priceMarginField.text

    property alias cfg_bgColor: bgColor.color
    property alias cfg_bgOpacity: bgOpacity.value
    property alias cfg_headerColor: headerColor.color
    property alias cfg_shadowColor: shadowColor.color
    
    property alias cfg_highColor: highColor.color
    property alias cfg_mediumColor: mediumColor.color
    property alias cfg_lowColor: lowColor.color
    
    property alias cfg_highThreshold: highThreshold.value
    property alias cfg_lowThreshold: lowThreshold.value

    Kirigami.FormLayout {
        id: page


        Component.onCompleted: {
            if (!plasmoid.configuration.highColor)
                plasmoid.configuration.highColor = "#ff0000"
            if (!plasmoid.configuration.mediumColor)
                plasmoid.configuration.mediumColor = "#add8e6"
            if (!plasmoid.configuration.lowColor)
                plasmoid.configuration.lowColor = "#90ee90"
        }


        RowLayout {
            Kirigami.FormData.label: i18n("Marginaali (snt/kWh):")

            Button {
                text: "-"
                onClicked: {
                    const val = Math.max(0, parseFloat(priceMarginField.text) - 0.01)
                    priceMarginField.text = val.toFixed(2)
                    plasmoid.configuration.priceMargin = val
                }
            }

            TextField {
                id: priceMarginField
                width: 80
                text: plasmoid.configuration.priceMargin !== undefined
                    ? plasmoid.configuration.priceMargin.toFixed(2)
                    : "0.00"
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator {
                    bottom: 0.0
                    top: 100.0
                    decimals: 2
                }

                onEditingFinished: {
                    const val = parseFloat(text)
                    plasmoid.configuration.priceMargin = val
                }
            }

            Button {
                text: "+"
                onClicked: {
                    const val = Math.min(100, parseFloat(priceMarginField.text) + 0.01)
                    priceMarginField.text = val.toFixed(2)
                    plasmoid.configuration.priceMargin = val
                }
            }
        }

        /*Kirigami.DoubleSpinBox {
            id: priceMargin
            Kirigami.FormData.label: i18n("Marginaali (snt/kWh):")
            from: 0
            to: 100
            stepSize: 0.01
            decimals: 2
        }
*/
        KQControls.ColorButton {
            id: bgColor
            Kirigami.FormData.label: i18n("Taustaväri:")
            showAlphaChannel: false
        }

        Slider {
            id: bgOpacity
            from: 0
            to: 1
            stepSize: 0.01
            Kirigami.FormData.label: i18n("Taustan läpinäkyvyys:")
        }

        KQControls.ColorButton {
            id: headerColor
            Kirigami.FormData.label: i18n("Otsikon väri:")
            showAlphaChannel: false
        }

        KQControls.ColorButton {
            id: shadowColor
            Kirigami.FormData.label: i18n("Tekstin varjon väri:")
            showAlphaChannel: false
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Kalliin hinnan väri ja raja-arvo:")
            KQControls.ColorButton {
                id: highColor
                showAlphaChannel: false
            }
            SpinBox {
                id: highThreshold
                from: 0
                to: 100
                stepSize: 1
                // suffix: " snt/kWh"
                onValueChanged: {
                    if (value <= lowThreshold.value) {
                        value = lowThreshold.value + 1;
                    }
                    plasmoid.configuration.highThreshold = value;
                }
            }
        }

        KQControls.ColorButton {
            id: mediumColor
            Kirigami.FormData.label: i18n("Keskihinnan väri:")
            showAlphaChannel: false
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Halvan hinnan väri ja raja-arvot:")
            KQControls.ColorButton {
                id: lowColor
                showAlphaChannel: false
            }
            SpinBox {
                id: lowThreshold
                from: 0
                to: 100
                stepSize: 1
                // suffix: " snt/kWh"
                onValueChanged: {
                    if (value >= highThreshold.value) {
                        value = highThreshold.value - 1;
                    }
                    plasmoid.configuration.lowThreshold = value;
                }
            }
        }

        Button {
            text: i18n("Palauta oletukset")
            onClicked: {
                plasmoid.configuration.priceMargin = 0.49
                plasmoid.configuration.highColor = "#ff0000"
                plasmoid.configuration.mediumColor = "#00aaff"
                plasmoid.configuration.lowColor = "#90ee90"
                plasmoid.configuration.bgColor = "black"
                plasmoid.configuration.bgOpacity = 0.5
                plasmoid.configuration.shadowColor = "black"
                plasmoid.configuration.headerColor = "#eeeeee"
                plasmoid.configuration.highThreshold = 20
                plasmoid.configuration.lowThreshold = 8

                // Päivitä myös UI
                priceMargin.value = 0.49
                highColor.color = "#ff0000"
                mediumColor.color = "#00aaff"
                lowColor.color = "#90ee90"
                bgColor.color = "black"
                shadowColor.color = "black"
                headerColor.color = "#eeeeee"
                highThreshold.value = 20
                lowThreshold.value = 8
                bgOpacity.value = 0.5
            }
        }
        
    }
}
