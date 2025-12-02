import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0

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
    property var sortedQuarterlyPrices: []
    property var hourlyPrices: []
    property int currentHour: (new Date()).getHours()
    property int currentMinute: Math.floor((new Date()).getMinutes() / 15) * 15

    onQuarterlyPricesChanged: {
        updateSortedQuarterlies()
        priceGraph.requestPaint()
    }
    onHourlyPricesChanged: priceGraph.requestPaint()


    ///// TIMERIT

    Timer {
        id: timeUpdater
        interval: 1000 * 10 // 10 sekunnin välein; riittää päivitykseen
        running: true
        repeat: true
        onTriggered: {
            var now = new Date()
            var nextQuarter = Math.ceil((now.getMinutes() + 1) / 15) * 15
            // päivitä currentHour/currentMinute
            currentHour = now.getHours()
            currentMinute = Math.floor(now.getMinutes() / 15) * 15
        }
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

    /////////////////////
    /// PÄÄNÄKYMÄ ///////

    Rectangle {
        anchors.fill: parent
        color: plasmoid.configuration.bgColor ?? "#1E1E1E"
        opacity: plasmoid.configuration.bgOpacity ?? 1.0
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

    function updateSortedQuarterlies() {
        let arr = root.quarterlyPrices.slice();  // kopio
        arr.sort((a, b) => {
            let ha = Number(a.hour);
            let hb = Number(b.hour);
            if (ha !== hb) return ha - hb;
            return Number(a.minute ?? 0) - Number(b.minute ?? 0);
        });
        root.sortedQuarterlyPrices = arr;
    }

    /////////////////////////////////////////
    ///////////////// POPUP /////////////////
    
    Popup {
        id: pricePopup
        width: 450
        height: 250
        modal: true
        focus: true
        z: 1
        // vain ulkopuolella klikkaus sulkee
        // closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

        onOpened: {
            let idx = findCurrentIndex()
            if (idx >= 0) {
                hourlyList.positionViewAtIndex(idx, ListView.Center)
            }
        }
        
        MouseArea {
            anchors.fill: parent
            z: 1
            propagateComposedEvents: true
            preventStealing: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: {
                if (!timeSwitch.containsMouse) {
                    pricePopup.close()
                }
            }
            onPressed: {
                if (timeSwitch.containsMouse) {
                    mouse.accepted = false   // anna tapahtuma Switchille
                }
            }
            onEntered: closeTimer.stop()
            onExited: closeTimer.start()
        }
        
        Timer {
            id: closeTimer
            interval: 3000  // 1 sekunti
            repeat: false
            onTriggered: pricePopup.close()
        }
        
        background: Rectangle {
            color: "#222"
            radius: 8
            border.color: root.plasmoid ? root.plasmoid.configuration.headerColor ?? "#FFD966" : "#FFD966"
            opacity: root.plasmoid ? root.plasmoid.configuration.bgOpacity ?? 0.95 : 0.95
            
            
        }
        
        ColumnLayout { 
            anchors.fill: parent
            spacing: 8
            z: 2
            RowLayout {
                //anchors.fill: parent
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Sähkön hinta tänään"
                    font.pixelSize: 20
                    font.bold: true
                    color: root.plasmoid.configuration.headerColor ?? "#FFD966"
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "1h"
                    font.pixelSize: 14
                    color: "white"
                    Layout.alignment: Qt.AlignVCenter
                }

                
                Switch {
                    id: timeSwitch
                    checked: root.plasmoid.configuration.showQuarterly || false
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                    // korvataan oletus-indikaattori
                    indicator: Rectangle {
                        id: track
                        width: 60
                        height: 24
                        radius: height/2
                        color: "#888"

                        Rectangle {
                            id: thumb
                            width: 20
                            height: 20
                            radius: 10
                            y: 2
                            x: timeSwitch.checked ? track.width - width - 2 : 2
                            color: "#FFD966"

                            Behavior on x {
                                NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                            }
                        }
                    }

                    onToggled: {
                        closeTimer.stop()
                        root.plasmoid.configuration.showQuarterly = checked
                        Qt.callLater(function() {
                            let idx = pricePopup.findCurrentIndex()
                            if (idx >= 0) {
                                hourlyList.positionViewAtIndex(idx, ListView.Center)
                            }
                            priceGraph.requestPaint()
                        })
                    }
                }

                Text {
                    text: "15min"
                    font.pixelSize: 14
                    color: "white"
                    Layout.alignment: Qt.AlignVCenter
                }

                
            }

            RowLayout {
                z: -100
            
                ListView {
                    id: hourlyList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    z: 0
                    model: (root.plasmoid.configuration.showQuarterly ? root.sortedQuarterlyPrices : root.hourlyPrices)
                    delegate: Row {
 
                        spacing: 10

                        // Helpot muuttujat
                        property int itemHour: Number(modelData.hour)
                        property int itemMinute: Number(modelData.minute ?? 0)

                        // Kumpi on "nykyinen" aika
                        property bool isCurrent: root.plasmoid.configuration.showQuarterly
                        ? (itemHour === currentHour && itemMinute === currentMinute)
                        : (itemHour === currentHour)

                        //property bool isCurrent: Number(modelData.hour) === currentHour

                        Text {
                            text: root.plasmoid.configuration.showQuarterly
                            ? (itemHour + ":" + (itemMinute < 10 ? "0" + itemMinute : itemMinute))
                            : (itemHour + ":00")

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
                    } // Row
                    
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded   // vaihtoehdot: AlwaysOn, AlwaysOff, AsNeeded
                        interactive: false            // käyttäjä voi vetää palkkia
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pricePopup.close()
                        }
                    }
                    
                } // ListView 

                // Oikealla graafi
                
                Canvas {
                    id: priceGraph
                    width: 220  // voit vaihtaa tarpeen mukaan
                    Layout.fillHeight: true
                    
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        // valitaan oikea data: tunti vai vartti
                        var prices = root.plasmoid.configuration.showQuarterly ? root.sortedQuarterlyPrices : root.hourlyPrices
                        if (prices.length === 0) return

                        // laske min ja max hintatasot
                        var minPrice = Math.min(...prices.map(p => p.price || 0))
                        var maxPrice = Math.max(...prices.map(p => p.price || 0))
                        
                        if (minPrice === maxPrice) maxPrice += 1  // välttää nolladivision

                        var barCount = prices.length
                        var barWidth = width / barCount

                        var now = new Date()
                        var currentHour = now.getHours()
                        var currentMinute = now.getMinutes()
                        var currentQuarter = Math.floor(currentMinute / 15) * 15

                        for (var i = 0; i < barCount; i++) {
                            var item = prices[i]
                            var p = item.price || 0
                            var barHeight = 5 + ((p - minPrice) / (maxPrice - minPrice)) * height
                            var x = i * barWidth
                            var y = height - barHeight

                            // tarkista, onko kyseessä nykyinen pylväs
                            var isCurrent = root.plasmoid.configuration.showQuarterly
                                ? (Number(item.hour) === currentHour && Number(item.minute) === currentQuarter)
                                : (Number(item.hour) === currentHour)

                            // väri hintatason mukaan
                            if (p < (root.plasmoid.configuration.lowThreshold ?? 8)) ctx.fillStyle = "#7CFF4C"
                            else if (p < (root.plasmoid.configuration.highThreshold ?? 20)) ctx.fillStyle = "#4CA6FF"
                            else ctx.fillStyle = "#FF4C4C"

                            // jos nykyinen, hehkuu valkoisena
                            if (isCurrent) {
                                ctx.fillStyle = "#FFFFFF"
                                
                                ctx.beginPath()
                                var triangleX = x + barWidth*0.4
                                var triangleY = y - 6
                                var size = 6
                                // Piirretään kärjellään oleva kolmio
                                ctx.moveTo(triangleX, triangleY + size)   // kärki alaspäin
                                ctx.lineTo(triangleX - size/2, triangleY) // vasen kulma
                                ctx.lineTo(triangleX + size/2, triangleY) // oikea kulma
                                ctx.closePath()
                                ctx.fill()
                            }


                            ctx.fillRect(x, y, barWidth * 0.8, barHeight) // jätetään pieni rako
                            
                        }
                    }  // onPaint
                } //Canvas

            } // RowLayout
        } // ColumnLayout

        
        function findCurrentIndex() {
            let now = new Date()
            let nowHour = now.getHours().toString().padStart(2, "0")
            let nowMinute = now.getMinutes()

            let list = plasmoid.configuration.showQuarterly
            ? sortedQuarterlyPrices
            : hourlyPrices

            for (let i = 0; i < list.length; i++) {
                let item = list[i]

                if (plasmoid.configuration.showQuarterly) {
                    // Varttihinnat: match hour + quarter
                    let itemHour = item.hour
                    let itemMinute = Number(item.minute)

                    // Nyt haetaan oikea vartti: 0, 15, 30, 45
                    let currentQuarter = Math.floor(nowMinute / 15) * 15

                    if (itemHour === nowHour && itemMinute === currentQuarter) {
                        return i
                    }

                } else {
                    // Tuntihinnat: match hour only
                    if (item.hour === nowHour) {
                        return i
                    }
                }
            }

                return -1
        }

        
    } // Popup
    
    

    

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
