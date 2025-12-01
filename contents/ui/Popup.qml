import QtQuick 2.15
import QtQuick.Controls 2.15

Popup {
    id: pricePopup
    width: 220
    height: 280
    modal: true
    focus: true
    
    property var hourlyPrices
    property var configuration
    // property var plasmoid: null

    background: Rectangle {
        color: "#222"
        radius: 8
        border.color: configuration?.headerColor ?? "#FFD966"
        opacity: Number(configuration?.bgOpacity ?? 0.95)
    }
    
    Column { 
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8
        
        Text {
            text: "Tuntihinnat"
            font.pixelSize: 20
            font.bold: true
            color: configuration.headerColor ?? "#FFD966"
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        ListView {
            id: hourlyList
            width: parent.width
            height: parent.height - 40 
            clip: true
            model: root.hourlyPrices
            delegate: Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Text { text: modelData.hour + ":00"; color: configuration?.headerColor ?? "white" }
                Text { 
                    text: modelData.price !== null ? (Number(modelData.price) + Number(configuration?.priceMargin || 0)).toFixed(2) + " snt/kWh" : "puuttuu" 
                    color: modelData.price !== null
                           ? getPriceColor(modelData.price)
                           : "gray"
                }
            }
        }
    }

    function getPriceColor(price) {
        let lowThreshold = configuration?.lowThreshold ?? 8
        let highThreshold = configuration?.highThreshold ?? 20

        if (price < lowThreshold - 1)
            return configuration.lowColor ?? "#7CFF4C"
        else if (price < highThreshold - 1)
            return configuration?.mediumColor ?? "#4CA6FF"
        else
            return configuration?.highColor ?? "#FF4C4C"
    }

    Component.onCompleted: {
        if (!plasmoid) {
            console.log("Popup loaded, but plasmoid not yet set.")
        }
        console.log("PriceMargin =", configuration.priceMargin)
        console.log("PriceMargin =", plasmoid.configuration.priceMargin)
        console.log("PriceMargin =", root.plasmoid.configuration.priceMargin)
    }
    
}

