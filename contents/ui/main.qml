import QtQuick 2.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid 2.0

// import "." as Components

PlasmoidItem {
    id: root
    width: 300
    height: width / 2
    onWidthChanged: height = width / 2

    property real price: -100
    property real margin: plasmoid.configuration.priceMargin ?? 0.49
    property string priceTrend: "-"
    property var allPrices: []
    property var quarterlyPrices: []
    property var hourlyPrices: []
    property int currentHour: new Date().getHours()


    Rectangle {
        anchors.fill: parent
        color: plasmoid.configuration.bgColor ?? "#1E1E1E"
        opacity: plasmoid.configuration.bgOpacity ?? 1.0
    }

    Timer {
        id: hourlyTimer
        interval: 1000 // alustavasti 1s, korvataan heti
        running: true
        repeat: false
        onTriggered: {
            loadPrice();
            // Aseta uusi ajastin seuraavaan täyteen tuntiin + 5s
            interval = getNextUpdateInterval();
            restart();
        }
    }
    
    Timer {
        id: dailyTimer
        repeat: true
        onTriggered: fetchPrices()
    }

    Column {
        anchors.centerIn: parent
        spacing: 4

        Text {
            text: "Sähkön hinta"
            font.family: "Helvetica"
            font.bold: false
            font.pixelSize: root.height * 0.2
            color: plasmoid.configuration.headerColor ?? "#FFD966"
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
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


    function getNextUpdateInterval() {
        var now = new Date();
        var nextHour = new Date(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours() + 1, 0, 5);
        return nextHour.getTime() - now.getTime();
    }
    
    function getNextMidnightInterval() {
        var now = new Date()
        var nextMidnight = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 10)
        return nextMidnight.getTime() - now.getTime()
    }

    function getColor(price) {
        let lowThreshold = plasmoid.configuration.lowThreshold ?? 8;
        let highThreshold = plasmoid.configuration.highThreshold ?? 20;

        if (price < lowThreshold - 1) return plasmoid.configuration.lowColor ?? "#7CFF4C";
        else if (price < highThreshold - 1) return plasmoid.configuration.mediumColor ?? "#4CA6FF";
        else return plasmoid.configuration.highColor ?? "#FF4C4C";
    }


    function loadPrice() {
        console.log("Yritetään hakea hintatietoja...");

        var now = new Date();
        var year = now.getFullYear();
        var month = ("0" + (now.getMonth() + 1)).slice(-2);
        var day = ("0" + now.getDate()).slice(-2);
        var hour = ("0" + now.getHours()).slice(-2);

        var currentUrl = `https://api.porssisahko.net/v1/price.json?date=${year}-${month}-${day}&hour=${hour}`;
        var nextHourUrl = `https://api.porssisahko.net/v1/price.json?date=${year}-${month}-${day}&hour=${("0" + (now.getHours() + 1)).slice(-2)}`;

        var xhrCurrent = new XMLHttpRequest();
        xhrCurrent.open("GET", currentUrl);
        xhrCurrent.timeout = 5000; // 5 sekuntia
        xhrCurrent.onreadystatechange = function () {
            if (xhrCurrent.readyState === XMLHttpRequest.DONE) {
                if (xhrCurrent.status === 200) {
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
                } else {
                    retrySoon();
                }
            }
        };
        xhrCurrent.onerror = function () {
            retrySoon();
        };
        xhrCurrent.ontimeout = function () {
            retrySoon();
        };
        xhrCurrent.send();
    }
    
    function fetchPrices() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://api.porssisahko.net/v2/latest-prices.json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                try {
                    var response = JSON.parse(xhr.responseText)
                    allPrices = response.prices

                    const todayDateStr = new Date().toLocaleDateString("sv-SE")

                    quarterlyPrices = allPrices
                        .filter(item => new Date(item.startDate).toLocaleDateString("sv-SE") === todayDateStr)
                        .map(item => {
                            const localDate = new Date(item.startDate)
                            return {
                                hour: localDate.getHours().toString().padStart(2, "0"),
                                minute: localDate.getMinutes().toString().padStart(2, "0"),
                                price: item.price
                            }
                        })

                    const hourlyMap = {}
                    quarterlyPrices.forEach(q => {
                        if (!hourlyMap[q.hour]) hourlyMap[q.hour] = []
                        hourlyMap[q.hour].push(q.price)
                    })

                    hourlyPrices = Object.keys(hourlyMap).map(hour => {
                        const prices = hourlyMap[hour]
                        if (prices.length === 4) {
                            const avg = prices.reduce((a, b) => a + b, 0) / prices.length
                            return { hour, price: avg }
                        } else {
                            console.warn("⚠️ Tunnilta puuttuu vartteja:", hour)
                            return { hour, price: null }
                        }
                    }).sort((a, b) => parseInt(a.hour) - parseInt(b.hour))

                    // console.log("All: ", allPrices)

                } catch (e) {
                    console.log("JSON-virhe:", e)
                    hourlyPrices = []
                }
            }
        }
        xhr.send()
    }

    
    
    
    Popup {
        id: pricePopup
        width: 220
        height: 250
        modal: true
        focus: true

        onOpened: {
            let idx = findCurrentHourIndex()
            if (idx >= 0) {
                hourlyList.positionViewAtIndex(idx, ListView.Center)
            }
        }
        
        background: Rectangle {
            color: "#222"
            radius: 8
            border.color: root.plasmoid ? root.plasmoid.configuration.headerColor ?? "#FFD966" : "#FFD966"
            opacity: root.plasmoid ? root.plasmoid.configuration.bgOpacity ?? 0.95 : 0.95

        }
        
        Column { 
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            
            Text {
                text: "Tuntihinnat"
                font.pixelSize: 20
                font.bold: true
                color: root.plasmoid.configuration.headerColor ?? "#FFD966"
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
                    //anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    
                    property bool isCurrent: Number(modelData.hour) === currentHour
                    
                    Text { 
                        text: modelData.hour + ":00"
                        color: isCurrent ? "yellow" : "white"
                        font.bold: isCurrent
                        font.pixelSize: 16
                        
                        SequentialAnimation on color {
                            running: isCurrent
                            loops: Animation.Infinite
                            ColorAnimation { from: "yellow"; to: "red"; duration: 500 }
                            ColorAnimation { from: "red"; to: "yellow"; duration: 500 }
                        }
                    }
                    Text { 
                        text: modelData.price !== null 
                            ? (Number(modelData.price) + margin).toFixed(2) + " snt/kWh"
                            : "puuttuu"
                        font.pixelSize: 16
                        font.bold: isCurrent
                        color: modelData.price !== null
                            ? getColor(modelData.price)
                            : "gray"
                    }
                }
            }
        }
        
        function findCurrentHourIndex() {
            let nowHour = new Date().getHours().toString().padStart(2, "0")
            for (let i = 0; i < hourlyPrices.length; i++) {
                if (hourlyPrices[i].hour === nowHour) {
                    return i
                }
            }
            return -1
        }
        
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: pricePopup.close()
            onEntered: closeTimer.stop()
            onExited: closeTimer.start()
        }
        
        Timer {
            id: closeTimer
            interval: 3000  // 1 sekunti
            repeat: false
            onTriggered: pricePopup.close()
        }
        
    }
    
    

    

    // Tämä funktio asettaa uuden 30 sekunnin ajastimen jos haku epäonnistui
    function retrySoon() {
        console.log("Verkkovirhe tai timeout – yritetään uudelleen 30 sekunnin päästä");
        Qt.createQmlObject(
            `import QtQuick 2.0; Timer {
                interval: 1 * 30 * 1000;
                running: true;
                repeat: false;
                onTriggered: loadPrice();
            }`,
            plasmoid,
            "RetryTimer"
        );
    }
    
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onClicked: function(mouse) {
            pricePopup.open()
        }
    }

    Component.onCompleted: {
        hourlyTimer.interval = getNextUpdateInterval();
        hourlyTimer.start();
        dailyTimer.interval = getNextMidnightInterval()
        dailyTimer.start()
        console.log("Plasmoid valmis");
        loadPrice();
        fetchPrices();
    }
}
