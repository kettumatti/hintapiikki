import QtQuick 2.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid 2.0

PlasmoidItem {
    id: root
    width: 300
    height: width / 2
    onWidthChanged: height = width / 2

    property int retryInterval: 2 * 60 * 1000 // 2 minuuttia
    property var retryTimer: null
    property real price: -100
    property real margin: plasmoid.configuration.priceMargin ?? 0.49
    property string priceTrend: "-"

    Rectangle {
        anchors.fill: parent
        color: plasmoid.configuration.bgColor ?? "black"
        opacity: plasmoid.configuration.bgOpacity ?? 0.5
    }

    /* Timer {
        interval: getNextUpdateInterval(); running: true; repeat: true
        onTriggered: loadPrice()
    }
    */


    
    Column {
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: "Pörssisähkön hinta"
            font.family: "Helvetica"
            font.bold: false
            font.pixelSize: root.height * 0.2
            color: plasmoid.configuration.headerColor ?? "#eeeeee"
        }
        
        Row {
            spacing: 5

            Text {
                id: priceText
                font.family: "Arial"
                font.bold: true
                font.pixelSize: root.height * 0.45
                color: isNaN(price) ? "gray" : getColor(price)
                text: isNaN(price) || price === -100 ? "N/A" : (price + margin).toFixed(2).replace('.', ',')
            }

            Text {
                font.family: "Arial"
                font.pixelSize: root.height * 0.15
                color: isNaN(price) ? "gray" : getColor(price)
                text: "snt/kWh"
                anchors.baseline: priceText.baseline
            }

            Text {
                font.pixelSize: root.height * 0.2
                color: root.priceTrend === "▲" ? "red" : root.priceTrend === "▼" ? "green" : "gray"
                text: root.priceTrend
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }


    function getColor(price) {
        let lowThreshold = plasmoid.configuration.lowThreshold ?? 8;
        let highThreshold = plasmoid.configuration.highThreshold ?? 20;

        if (price < lowThreshold) return plasmoid.configuration.lowColor ?? "#90ee90";
        else if (price < highThreshold) return plasmoid.configuration.mediumColor ?? "#00aaff";
        else return plasmoid.configuration.highColor ?? "#ff0000";
    }

    /*
    function getNextUpdateInterval() {
        var now = new Date();
        var nextHour = new Date(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours() + 1, 0, 5);
        return nextHour.getTime() - now.getTime();
    }

    function loadPrice() {
        var now = new Date();
        var year = now.getFullYear();
        var month = ("0" + (now.getMonth() + 1)).slice(-2);
        var day = ("0" + now.getDate()).slice(-2);
        var hour = ("0" + now.getHours()).slice(-2);

        var currentUrl = `https://api.porssisahko.net/v1/price.json?date=${year}-${month}-${day}&hour=${hour}`;
        var nextHourUrl = `https://api.porssisahko.net/v1/price.json?date=${year}-${month}-${day}&hour=${("0" + (now.getHours() + 1)).slice(-2)}`;

        var xhrCurrent = new XMLHttpRequest();
        xhrCurrent.open("GET", currentUrl);
        xhrCurrent.onreadystatechange = function () {
            if (xhrCurrent.readyState === XMLHttpRequest.DONE && xhrCurrent.status === 200) {
                var response = JSON.parse(xhrCurrent.responseText);
                var val = parseFloat(response.price);
                price = !isNaN(val) ? val : -1;

                var xhrNext = new XMLHttpRequest();
                xhrNext.open("GET", nextHourUrl);
                xhrNext.onreadystatechange = function () {
                    if (xhrNext.readyState === XMLHttpRequest.DONE && xhrNext.status === 200) {
                        var nextResponse = JSON.parse(xhrNext.responseText);
                        var nextVal = parseFloat(nextResponse.price);
                        priceTrend = !isNaN(nextVal)
                            ? (nextVal > price ? "▲" : nextVal < price ? "▼" : " -")
                            : " -";
                    } else {
                        priceTrend = " -";
                    }
                };
                xhrNext.send();
            }
        };
        xhrCurrent.send();
    }
    */
    
    
    function scheduleNextUpdate(interval) {
        if (retryTimer !== null) {
            clearTimeout(retryTimer);
        }
        retryTimer = setTimeout(loadPrice, interval);
    }

    function loadPrice() {
        var now = new Date();
        var year = now.getFullYear();
        var month = ("0" + (now.getMonth() + 1)).slice(-2);
        var day = ("0" + now.getDate()).slice(-2);
        var hour = ("0" + now.getHours()).slice(-2);

        var currentUrl = `https://api.porssisahko.net/v1/price.json?date=${year}-${month}-${day}&hour=${hour}`;
        var nextHourUrl = `https://api.porssisahko.net/v1/price.json?date=${year}-${month}-${day}&hour=${("0" + (now.getHours() + 1)).slice(-2)}`;

        var xhrCurrent = new XMLHttpRequest();
        xhrCurrent.open("GET", currentUrl);
        xhrCurrent.onreadystatechange = function () {
            if (xhrCurrent.readyState === XMLHttpRequest.DONE) {
                if (xhrCurrent.status === 200) {
                    try {
                        var response = JSON.parse(xhrCurrent.responseText);
                        var val = parseFloat(response.price);
                        price = !isNaN(val) ? val : -1;

                        var xhrNext = new XMLHttpRequest();
                        xhrNext.open("GET", nextHourUrl);
                        xhrNext.onreadystatechange = function () {
                            if (xhrNext.readyState === XMLHttpRequest.DONE && xhrNext.status === 200) {
                                var nextResponse = JSON.parse(xhrNext.responseText);
                                var nextVal = parseFloat(nextResponse.price);
                                priceTrend = !isNaN(nextVal)
                                    ? (nextVal > price ? "▲" : nextVal < price ? "▼" : " -")
                                    : " -";
                            } else {
                                priceTrend = " -";
                            }

                            // ✅ Onnistunut päivitys — seuraava tunti
                            scheduleNextUpdate(getNextUpdateInterval());
                        };
                        xhrNext.onerror = function () {
                            console.log("Virhe haettaessa seuraavan tunnin hintaa.");
                            scheduleNextUpdate(retryInterval);
                        };
                        xhrNext.send();
                    } catch (e) {
                        console.log("JSON-virhe:", e);
                        scheduleNextUpdate(retryInterval);
                    }
                } else {
                    console.log("Hintadatan lataus epäonnistui. Status: " + xhrCurrent.status);
                    scheduleNextUpdate(retryInterval);
                }
            }
        };
        xhrCurrent.onerror = function () {
            console.log("Verkkovirhe haettaessa hintaa.");
            scheduleNextUpdate(retryInterval);
        };
        xhrCurrent.send();
    }
    
    
    

    Component.onCompleted: {
        console.log("Plasmoid valmis");
        loadPrice();
    }
}
