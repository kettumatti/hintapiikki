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
    property bool popupIsOpen: false
    
    onQuarterlyPricesChanged: {
        updateSortedQuarterlies()
        priceGraph.requestPaint()
    }
    onHourlyPricesChanged: priceGraph.requestPaint()

    
    //////////////////////////////////////////////////////////
    ////////////////////////// TIMERIT ///////////////////////
    //////////////////////////////////////////////////////////
    
    Timer {
        id: wakeChecker
        interval: 20000     // tarkistetaan 20s välein
        running: true
        repeat: true

        property double lastTime: Date.now()

        onTriggered: {
            let now = Date.now()
            let diff = now - lastTime

            // Jos aika hyppäsi yli 5 minuuttia,
            // kone on todennäköisesti herännyt horroksesta
            if (diff > 5 * 60 * 1000) {
                fetchPrices()
            }

            lastTime = now
        }
    }

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
        id: refreshTimer
        interval: 10000
        running: true
        repeat: true
        onTriggered: showPrice()
    }
    
    Timer {
        id: retryTimer
        interval: 30 * 1000
        repeat: false
        running: false
        onTriggered: fetchPrices()
    }
    
    Timer {
        id: dailyTimer
        interval: 10000 // Alustava, joka korvataaan heti käynnistyksessä
        repeat: true
        onTriggered: fetchPrices()
    }
    
    Timer {
        id: closeTimer
        interval: 3000  // 3 sekuntia
        repeat: false
        onTriggered: popupClose()
    }

    
    ////////////////////////////////////////////////////////////
    ///////////////////////// FUNKTIOT /////////////////////////
    ////////////////////////////////////////////////////////////
    
    function popupClose() {
        pricePopup.close()
        popupIsOpen = false
        showPrice()
    }

    function popupOpen(event) {
        positionPopup(event)
        pricePopup.open()
        popupIsOpen = true
    }
    
    function retrySoon() {
        console.log("Verkkovirhe tai timeout – yritetään uudelleen 30 sekunnin päästä");
        retryTimer.restart()
    }

    function getNextMidnightInterval() {
        var now = new Date()
        var nextMidnight = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 5)
        return nextMidnight.getTime() - now.getTime()
    }

    function getColor(price) {
        let lowThreshold = plasmoid.configuration.lowThreshold ?? 8;
        let highThreshold = plasmoid.configuration.highThreshold ?? 20;

        if (price < lowThreshold - 1) return plasmoid.configuration.lowColor ?? "#7CFF4C";
        else if (price < highThreshold - 1) return plasmoid.configuration.mediumColor ?? "#4CA6FF";
        else return plasmoid.configuration.highColor ?? "#FF4C4C";
    }
  
    function showPrice() {

        // Varmista että data on olemassa
        if (!quarterlyPrices || !Array.isArray(quarterlyPrices)) quarterlyPrices = [];
        if (!hourlyPrices || !Array.isArray(hourlyPrices)) hourlyPrices = [];

        var now = new Date();
        var h = now.getHours();   // numero 0–23
        var m = now.getMinutes(); // numero 0–59

        // Erottele logiikka asetuksen mukaan
        if (plasmoid.configuration.showQuarterly) {
            // --- Varttihinta ---
            var quarter = m < 15 ? 0 : m < 30 ? 15 : m < 45 ? 30 : 45; // numero

            // Yritä ensin numerokentillä, sitten merkkijonilla (fallback)
            var q = quarterlyPrices.find(item =>
                (item.hour === h && item.minute === quarter) ||
                (item.hour === h.toString().padStart(2, "0") && item.minute === quarter.toString().padStart(2, "0"))
            );

            if (!q) {
                console.warn("showPrice: Ei varttiriviä tunnille", h, ":", quarter, "— tarkista datan tyypit ja päiväsuodatus");
            }

            price = q && typeof q.price === "number" ? q.price : null;

            // Trend seuraavaan varttiin
            var nextMinute = (quarter + 15) % 60;
            var nextHour = h + (nextMinute === 0 ? 1 : 0);
            var nextQ = quarterlyPrices.find(item =>
                (item.hour === nextHour && item.minute === nextMinute) ||
                (item.hour === nextHour.toString().padStart(2, "0") && item.minute === nextMinute.toString().padStart(2, "0"))
            );

            priceTrend = (nextQ && price != null)
                ? (nextQ.price > price ? "▲" : nextQ.price < price ? "▼" : " -")
                : " -";

        } else {
            // --- Tuntihinta ---
            var row = hourlyPrices.find(item =>
                item.hour === h || item.hour === h.toString().padStart(2, "0")
            );

            if (!row) {
                console.log("hourlyPrices:", JSON.stringify(hourlyPrices, null, 2));
                console.warn("showPrice: Ei tuntiriviä tunnille", h, "— tarkista datan tyypit ja päiväsuodatus");
            }

            price = row && typeof row.price === "number" ? row.price : null;

            // Trend seuraavaan tuntiin
            var nh = h + 1;
            var nextRow = hourlyPrices.find(item =>
                item.hour === nh || item.hour === nh.toString().padStart(2, "0")
            );

            priceTrend = (nextRow && price != null)
                ? (nextRow.price > price ? "▲" : nextRow.price < price ? "▼" : " -")
                : " -";
        }

    }
    
    function fetchPrices() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://api.porssisahko.net/v2/latest-prices.json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                // Tarkista HTTP-status
                if (xhr.status !== 200) {
                    console.warn("fetchPrices: HTTP virhe:", xhr.status)
                    retrySoon()
                    return  
                }
                
                try {
                    var response = JSON.parse(xhr.responseText)
                    
                    // Uusien tietojen validointi
                    if (!response.prices || !Array.isArray(response.prices)) {
                        console.warn("fetchPrices: Datamuoto virheellinen")
                        retrySoon()
                        return
                    }
                    
                    allPrices = response.prices

                    const todayDateStr = new Date().toLocaleDateString("sv-SE")

                    const newQuarterly = allPrices
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
                    newQuarterly.forEach(q => {
                        if (!hourlyMap[q.hour]) hourlyMap[q.hour] = []
                        hourlyMap[q.hour].push(q.price)
                    })

                    const newHourly = Object.keys(hourlyMap).map(hour => {
                        const prices = hourlyMap[hour]
                        if (prices.length === 4) {
                            const avg = prices.reduce((a, b) => a + b, 0) / prices.length
                            return { hour, price: avg }
                        } else {
                            console.warn("Tunnilta puuttuu vartteja:", hour)
                            return { hour, price: null }
                        }
                    }).sort((a, b) => parseInt(a.hour) - parseInt(b.hour))

                    quarterlyPrices = newQuarterly
                    hourlyPrices = newHourly
                    showPrice();

                } catch (e) {
                    console.log("JSON-virhe:", e)
                    hourlyPrices = []
                }
            }
        }
        xhr.onerror = function () {
            retrySoon();
        };
        xhr.ontimeout = function () {
            retrySoon();
        };
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

    function positionPopup() {
        if (!pricePopup) return

        var popupWidth = pricePopup.width;
        var popupHeight = pricePopup.height;

        // Appletti vasen yläkulma globaalisti
        var appletPos = root.mapToGlobal(Qt.point(0,0));

        // Aluksi popup alkaa normaalisti applettiin nähden
        var x = 0;
        var y = 0;

        // Jos popup ylittää ruudun oikean reunan, siirrä negatiiviseksi
        var overflowX = (appletPos.x + popupWidth) - (Screen.width - 60)
        if (overflowX > 0) {
            x = -overflowX;
        }

        // Jos popup ylittää ruudun alareunan, siirrä negatiiviseksi
        var overflowY = (appletPos.y + popupHeight) - (Screen.height - 60)
        if (overflowY > 0) {
            y = -overflowY
        }

        pricePopup.x = x
        pricePopup.y = y

    }

    
    /////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////// PÄÄNÄKYMÄ /////////////////////////////////
    /////////////////////////////////////////////////////////////////////////////

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


    ///////////////////////////////////////////////////////////////////////
    ////////////////////////////////// POPUP //////////////////////////////
    ///////////////////////////////////////////////////////////////////////
    
    Popup {
        id: pricePopup
        width: 500
        height: 250
        modal: false
        focus: true      
        z: 1
        
        property int popupX: 0
        property int popupY: 0

        onOpened: {
            popupIsOpen = true
            
            let idx = findCurrentIndex()
            if (idx >= 0) {
                hourlyList.positionViewAtIndex(idx, ListView.Center)
            }
            
            if (root.x + width > Screen.width) {
                popupX = Screen.width - width - 50
            }

        }        
        
        MouseArea {
            id: popupMouse
            anchors.fill: parent
            z: 1
            propagateComposedEvents: true
            preventStealing: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: {
                if (!timeSwitch.containsMouse) {
                    popupClose()
                    closeTimer.stop()
                }
            }
            onEntered: closeTimer.stop()
            onExited: {
                Qt.callLater(function() {
                    if (!rootMouse.containsMouse && !popupMouse.containsMouse) {
                        closeTimer.start()
                    }
                })
            }
            
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
                        showPrice()
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
 
                        //spacing: 10

                        // Helpot muuttujat
                        property int itemHour: Number(modelData.hour)
                        property int itemMinute: Number(modelData.minute ?? 0)

                        // Kumpi on "nykyinen" aika
                        property bool isCurrent: root.plasmoid.configuration.showQuarterly
                        ? (itemHour === currentHour && itemMinute === currentMinute)
                        : (itemHour === currentHour)

                        Text {
                            text: root.plasmoid.configuration.showQuarterly
                                ? ((itemHour < 10 ? "0" + itemHour : itemHour)
                                + ":" + (itemMinute < 10 ? "0" + itemMinute : itemMinute) + "    ")
                                : ((itemHour < 10 ? "0" + itemHour : itemHour) + ":00    ")


                            color: isCurrent ? "yellow" : "white"
                            font.family: "Sans Serif" 
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
                            id: priceText
                            text: modelData.price !== null
                                ? (Number(modelData.price) + margin).toFixed(2) : "N/A"
    
                            font.family: "Sans Serif" 
                            font.pixelSize: 16
                            font.bold: isCurrent
                            color: modelData.price !== null
                                ? getColor(modelData.price)
                                : "gray"
                        }
                        Text {
                            text: " snt/kWh"
                            anchors.baseline: priceText.baseline
                            font.family: "Sans Serif" 
                            font.pixelSize: 12
                            font.bold: isCurrent
                            color: modelData.price !== null
                                ? getColor(modelData.price)
                                : "gray"
                        }
                    } // Row
                    
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded   // vaihtoehdot: AlwaysOn, AlwaysOff, AsNeeded
                        interactive: false
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            popupClose()
                            closeTimer.stop()
                        }
                    }
                    
                } // ListView 

                // Oikealla graafi
                
                Canvas {
                    id: priceGraph
                    width: 300  // voit vaihtaa tarpeen mukaan
                    Layout.fillHeight: true
                    
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        // valitaan oikea data: tunti vai vartti
                        var prices = root.plasmoid.configuration.showQuarterly ? root.sortedQuarterlyPrices : root.hourlyPrices
                        if (prices.length === 0) return

                        // laske min ja max hintatasot
                        // var minPrice = Math.min(...prices.map(p => p.price || 0))
                        var minPrice = 0
                        var rawMax = Math.max(...prices.map(p => p.price || 0))
                        var maxPrice = Math.max(25, rawMax + 3 + margin)
                        
                        if (minPrice === maxPrice) maxPrice += 1  // välttää nolladivision

                        // piirretään Y-akselin viivat ja numerot
                        ctx.fillStyle = "white"
                        //ctx.font = "Sans Serif"
                        ctx.textAlign = "right"
                        ctx.textBaseline = "middle"

                        for (var yValue = 0; yValue <= maxPrice; yValue += 5) {
                            var yPos = height - (yValue / maxPrice) * height
                            
                            // piirrä numero vain jos ei ole nolla
                            if (yValue !== 0) {
                                ctx.fillText(yValue.toString(), 30, yPos)
                            }
                            // viiva akselille
                            ctx.strokeStyle = "rgba(255,255,255,0.2)"
                            ctx.beginPath()
                            ctx.moveTo(32, yPos)
                            ctx.lineTo(width, yPos)
                            ctx.stroke()
                        }
                        
                        var axisOffset = 40; // tilaa Y-akselin numeroille
                        
                        var barCount = prices.length
                        var barWidth = (width - axisOffset) / barCount

                        var now = new Date()
                        var currentHour = now.getHours()
                        var currentMinute = now.getMinutes()
                        var currentQuarter = Math.floor(currentMinute / 15) * 15

                        for (var i = 0; i < barCount; i++) {
                            var item = prices[i]
                            var p = item.price || 0
                            var barHeight = ((p + margin) / (maxPrice - minPrice)) * height
                            var x = axisOffset + i * barWidth
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
    
    property bool suppressExit: false
    
    MouseArea {
        id: rootMouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onClicked: (event) => {
            if (!popupIsOpen) {
                popupOpen()
                closeTimer.stop()
            }
            else {
                closeTimer.stop()
                popupClose()
                
            }
        }

        onExited: {
            if (!popupIsOpen) return
            Qt.callLater(function() {
                if (!rootMouse.containsMouse && !popupMouse.containsMouse) {
                    closeTimer.start()
                }
            })
        }
        onEntered: closeTimer.stop()
    }

    Component.onCompleted: {
        dailyTimer.interval = getNextMidnightInterval()
        dailyTimer.start()
        fetchPrices();
        
    }
}
