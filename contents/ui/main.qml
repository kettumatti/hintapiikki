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
    property var nextDay00: [] // Seuraavan päivän ensimmäisen tunnin hinnat
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
        interval: 10000     // tarkistetaan 10s välein
        running: true
        repeat: true

        property double lastTime: Date.now()

        onTriggered: {
            let now = Date.now()
            let diff = now - lastTime

            // Jos aika hyppäsi yli 3 minuuttia,
            // kone on todennäköisesti herännyt horroksesta
            if (diff > 3 * 60 * 1000) {
                updateCurrentTime()
                showPrice()
                quarterTimer.interval = getNextQuarterInterval()
                quarterTimer.start()
            }

            lastTime = now
        }
    }

    Timer {
        id: quarterTimer
        interval: getNextQuarterInterval()
        running: true
        repeat: false
        
        onTriggered: {
            updateCurrentTime()
            showPrice()

            // Aseta seuraava laukaisu
            interval = getNextQuarterInterval()
            start()
        }
    }
  
    Timer {
        id: retryTimer
        interval: 10 * 1000 // 10 sekuntia
        repeat: false
        running: false
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
    
    // Popupin sulkeminen ja avaaminen 
    
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
    
    // Päivitetään aika, jotta hintataulukosta pystytään korostamaan kuluvan tunnin/vartin hinta
    
    function updateCurrentTime() {
        var now = new Date()
        currentHour = now.getHours()
        currentMinute = Math.floor(now.getMinutes() / 15) * 15
    }
    
    // Uudelleenyritys datan hakemiseksi, jos esim. verkkoa ei ole.
    
    function retrySoon() {
        console.warn("[com.github.kettumatti.hintapiikki] Verkkovirhe tai timeout – yritetään hetken kuluttua uudelleen ");
        retryTimer.restart()
    }
   
    // Näkymän päivitys vartin välein
    
    function getNextQuarterInterval() {
        let now = new Date()
        let minutes = now.getMinutes()
        let nextQuarter = Math.floor(minutes / 15) * 15 + 15
        let nextHour = now.getHours()
        let nextDay = now.getDate()

        if (nextQuarter >= 60) {
            nextQuarter = 0
            nextHour += 1
            if (nextHour >= 24) {
                nextHour = 0
                nextDay += 1
            }
        }

        // seuraava päivitysaika + 1 sekunti
        let next = new Date(
            now.getFullYear(),
            now.getMonth(),
            nextDay,
            nextHour,
            nextQuarter,
            1, 0
        )

        return next.getTime() - now.getTime()
    }

    // Antaa värikoodin hinnan perusteella
    
    function getColor(price) {
        let lowThreshold = plasmoid.configuration.lowThreshold ?? 8;
        let highThreshold = plasmoid.configuration.highThreshold ?? 20;

//        const p = Math.round(price * 100) / 100
        const p = parseFloat(price.toFixed(2))
        
        if (p <= lowThreshold) {
            return plasmoid.configuration.lowColor ?? "#7CFF4C"
        }
        else if (p < highThreshold) {
            return plasmoid.configuration.mediumColor ?? "#4CA6FF";
        }
        else {
            return plasmoid.configuration.highColor ?? "#FF4C4C";
        }
    }
    
    // Tarkistaa, onko hintadata tältä päivältä
    
    function dataIsFromToday() {
        const last = plasmoid.configuration.lastFetchDate;
        if (!last)
            return false;

        const lastDate = new Date(last);
        const now = new Date();

        return lastDate.getFullYear() === now.getFullYear()
            && lastDate.getMonth() === now.getMonth()
            && lastDate.getDate() === now.getDate();
    }

    // Näyttää hinnan ja hintatrendin pääikkunassa. Kutsuu tarvittaessa fetchPrice-funktiota,
    // mikäli data on vanhentunutta tai seuraavan vuorokauden ensimmäisen tunnin hinnat puuttuvat.
  
    function showPrice() {
    
        if (!dataIsFromToday()) {
            fetchPrices();
            return;
        }
        
        // Jos ollaan klo 23 jälkeen ja huomisen klo 00–01 hinnat puuttuvat → hae
        if (currentHour >= 23 && (!nextDay00 || nextDay00.length === 0)) {
            fetchPrices()
            return
        }

        // Varmistetaan että data on olemassa
        if (!quarterlyPrices || !Array.isArray(quarterlyPrices)) quarterlyPrices = [];
        if (!hourlyPrices || !Array.isArray(hourlyPrices)) hourlyPrices = [];

        var now = new Date();
        var h = now.getHours();   // numero 0–23
        var m = now.getMinutes(); // numero 0–59

        // Erottellaan logiikka asetuksen mukaan
        if (plasmoid.configuration.showQuarterly) {
            // --- Varttihinta ---
            var quarter = m < 15 ? 0 : m < 30 ? 15 : m < 45 ? 30 : 45; // numero

            // Yritä ensin numerokentillä, sitten merkkijonilla (fallback)
            var q = quarterlyPrices.find(item =>
                (item.hour === h && item.minute === quarter) ||
                (item.hour === h.toString().padStart(2, "0") && item.minute === quarter.toString().padStart(2, "0"))
            );

            if (!q) {
                console.warn("[com.github.kettumatti.hintapiikki] Ei varttiriviä tunnille", h, ":", quarter, "— tarkista datan tyypit ja päiväsuodatus");
            }

            price = q && typeof q.price === "number" ? q.price : null;

            // Trend seuraavaan varttiin
            var nextMinute = (quarter + 15) % 60;
            var nextHour = h + (nextMinute === 0 ? 1 : 0);
            var nextQ = quarterlyPrices.find(item =>
                (item.hour === nextHour && item.minute === nextMinute) ||
                (item.hour === nextHour.toString().padStart(2, "0") && item.minute === nextMinute.toString().padStart(2, "0"))
            );

            // Jos ollaan klo 23:45, käytetään huomisen klo 00:00–00:15 varttia nextDay00-taulukosta
            if (!nextQ && h === 23 && quarter === 45 && nextDay00 && nextDay00.length > 0) {
                nextQ = nextDay00[0];  // huomisen ensimmäinen vartti HUOM! Datan järjestys päivän lopusta alkuun.
            }
            
            priceTrend = (nextQ && price != null)
                ? (nextQ.price > price ? "▲" : nextQ.price < price ? "▼" : " -")
                : " -"; 

        } else {
            // --- Tuntihinta ---
            var row = hourlyPrices.find(item =>
                item.hour === h || item.hour === h.toString().padStart(2, "0")
            );

            if (!row) {
                // console.log("[com.github.kettumatti.hintapiikki] ", JSON.stringify(hourlyPrices, null, 2));
                console.warn("[com.github.kettumatti.hintapiikki] Ei tuntiriviä tunnille", h, "— tarkista datan tyypit ja päiväsuodatus");
            }

            price = row && typeof row.price === "number" ? row.price : null;

            // Trend seuraavaan tuntiin
            var nh = h + 1;
            var nextRow = hourlyPrices.find(item =>
                item.hour === nh || item.hour === nh.toString().padStart(2, "0")
            );

            // Jos ollaan klo 23, käytetään huomisen klo 00–01 tuntihintaa nextDay00-taulukosta
            if (!nextRow && h === 23 && nextDay00 && nextDay00.length === 4) {
                const avg = nextDay00.reduce((a, b) => a + b.price, 0) / 4
                nextRow = { hour: "00", price: avg }
            }

            priceTrend = (nextRow && price != null)
                ? (nextRow.price > price ? "▲" : nextRow.price < price ? "▼" : " -")
                : " -";
        }
    }
    
    // Noutaa hintatiedot porssisahko.net -sivustolta
    
    function fetchPrices() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://api.porssisahko.net/v2/latest-prices.json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                // Tarkista HTTP-status
                if (xhr.status !== 200) {
                    console.warn("[com.github.kettumatti.hintapiikki] HTTP virhe:", xhr.status)
                    retrySoon()
                    return  
                }
                
                try {
                    var response = JSON.parse(xhr.responseText)
                    
                    // Uusien tietojen validointi
                    if (!response.prices || !Array.isArray(response.prices)) {
                        console.warn("[com.github.kettumatti.hintapiikki] Datamuoto virheellinen")
                        retrySoon()
                        return
                    }
                    
                    allPrices = response.prices

                    const todayDateStr = new Date().toLocaleDateString("sv-SE")
                    
                    const today = new Date()
                    const tomorrow = new Date(today)
                    tomorrow.setDate(today.getDate() + 1)
                    const tomorrowDateStr = tomorrow.toLocaleDateString("sv-SE")

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
                        
                    // Huomisen klo 00–01 vartit erikseen (UTC-pohjainen vertailu)
                        
                    const tomorrowQuarterly00 = []

                    for (let i = 0; i < allPrices.length; i++) {
                        const item = allPrices[i]
                        const d = new Date(item.startDate)

                        // Muunna Suomen ajaksi
                        const localHour = d.getHours()
                        const localDateStr = d.toLocaleDateString("sv-SE")

                        
                        // Suodatetaan vain huomisen 00:00–00:59
                        if (localDateStr === tomorrowDateStr && localHour === 0) {
                            tomorrowQuarterly00.push({
                                hour: localHour.toString().padStart(2, "0"),
                                minute: d.getMinutes().toString().padStart(2, "0"),
                                price: item.price
                            })
                        }
                    }
                    
                    tomorrowQuarterly00.reverse() // Käännetään data kronologiseen järjestykseen 00:00->00:45
        
                    //////////

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
                            console.warn("[com.github.kettumatti.hintapiikki] Tunnilta puuttuu vartteja:", hour)
                            return { hour, price: null }
                        }
                    }).sort((a, b) => parseInt(a.hour) - parseInt(b.hour))

                    quarterlyPrices = newQuarterly
                    hourlyPrices = newHourly

                    nextDay00 = tomorrowQuarterly00

                    plasmoid.configuration.lastFetchDate = new Date().toISOString()

                    showPrice();

                } catch (e) {
                    console.warn("[com.github.kettumatti.hintapiikki] JSON-virhe:", e)
                    hourlyPrices = []
                }
            }
        }
        xhr.onerror = function () {
            retrySoon()
        }
        xhr.ontimeout = function () {
            retrySoon()
        }
        xhr.send()
    }

    // Järjestelee 15 min hinnat kronologiseen järjestykseen
    
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

    // Säätää popupin paikkaa, mikäli appletti ruudun reunassa
    
    function positionPopup() {
        if (!pricePopup) return

        var popupWidth = pricePopup.width;
        var popupHeight = pricePopup.height;

        // Appletti vasen yläkulma globaalisti
        var appletPos = root.mapToGlobal(Qt.point(0, 0));

        // Popupin oletus koordinaatit appletin vasempaan yläkulmaan nähden
        var x = -100;
        var y = -70;

        // Jos applet on lähellä vasenta reunaa, älä siirrä popupia vasemmalle
        if (appletPos.x < 100) {
            x = 0;
        }

        // Jos applet on lähellä yläreunaa, älä siirrä popupia ylöspäin
        if (appletPos.y < 70) {
            y = 0;
        }
        
        // Jos popup ylittää ruudun oikean reunan, siirrä vasemmalle
        var overflowX = (appletPos.x + popupWidth) - (Screen.width - 60)
        if (overflowX > 0) {
            x = -overflowX;
        }

        // Jos popup ylittää ruudun alareunan, siirrä ylöspäin
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
        // opacity: plasmoid.configuration.bgOpacity ?? 1.0
    }

    Column {
        anchors.centerIn: parent
        spacing: 4
        
        Text {
            id: otsikkoText
            text: plasmoid.configuration.quarterlyPrices ? "Sähkön varttihinta" : "Sähkön tuntihinta"
            font.family: "Sans Serif"
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
        
        closePolicy: Popup.NoAutoClose
        
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

                    // korvataan oletus-"vipu"
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
                    delegate: RowLayout {
 
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
                                + ":" + (itemMinute < 10 ? "0" + itemMinute : itemMinute))
                                : ((itemHour < 10 ? "0" + itemHour : itemHour) + ":00")

                            Layout.preferredWidth: 50
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
                    
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignRight
                            
                            Text {
                                id: priceText
                                text: modelData.price !== null
                                    ? (Number(modelData.price) + margin).toFixed(2).replace(".", ",") : "N/A"
                                Layout.preferredWidth: 40
                                horizontalAlignment: Text.AlignRight
                                font.family: "Sans Serif" 
                                font.pixelSize: 16
                                font.bold: isCurrent
                                color: modelData.price !== null
                                    ? getColor(modelData.price + margin)
                                    : "gray"
                            }
                            Text {
                                id: unitText
                                text: " snt/kWh"
                                // anchors.baseline: priceText.baseline
                                horizontalAlignment: Text.AlignRight
                                font.family: "Sans Serif" 
                                font.pixelSize: 12
                                font.bold: isCurrent
                                color: modelData.price !== null
                                    ? getColor(modelData.price + margin)
                                    : "gray"
                            }
                        } // RowLayout (hinta ja yksikkö)
                    } // RowLayout
                    
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        interactive: false
                        width: 1
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
                    width: 310
                    Layout.fillHeight: true
                    
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)

                        // valitaan oikea data: tunti vai vartti
                        var prices = root.plasmoid.configuration.showQuarterly ? root.sortedQuarterlyPrices : root.hourlyPrices
                        if (prices.length === 0) return

                        // laske min ja max hintatasot
                        var rawMin = Math.min(...prices.map(p => p.price ?? 0))
                        var minPrice = Math.min(-0.2, rawMin - 1)
                        var rawMax = Math.max(...prices.map(p => p.price || 0))
                        var maxPrice = Math.max(7, rawMax + 2 + margin)
                        
                        if (minPrice === maxPrice) maxPrice += 1  // estää nollalla jakamisen
                            
                        // piirretään Y-akselin viivat ja numerot
                        ctx.fillStyle = "white"
                        //ctx.font = "10px sans-serif"
                        ctx.textAlign = "right"
                        ctx.textBaseline = "middle"

                        // Hintatasot sopivin välein (riippuen päivän korkeimmasta hinnasta)
                        const rawStep = maxPrice / 10;
                        const scaleBase = Math.pow(10, Math.floor(Math.log10(rawStep)));
                        const step = [1, 2, 5, 10].find(n => n * scaleBase >= rawStep) * scaleBase;
                        
                        const minRounded = Math.floor(minPrice / step) * step
                        const maxRounded = Math.ceil(maxPrice / step) * step

                        for (var yValue = minRounded; yValue <= maxRounded; yValue += step) {
                            var yPos = height - ((yValue - minPrice) / (maxPrice - minPrice)) * height

                            ctx.fillText(yValue.toString(), 30, yPos)

                            // viiva akselille
                            ctx.strokeStyle = "rgba(255,255,255,0.2)"
                            ctx.beginPath()
                            ctx.moveTo(32, yPos)
                            ctx.lineTo(width, yPos)
                            
                            if (yValue === 0) {
                                // Nollaviiva paksumpana ja kirkkaampana
                                ctx.strokeStyle = "rgba(255,255,255,0.7)"
                                ctx.lineWidth = 2
                            } else {
                                ctx.strokeStyle = "rgba(255,255,255,0.2)"
                                ctx.lineWidth = 1
                            }
                            
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
                            var p = (item.price ?? 0) + margin
                            var valueY = height - ((p - minPrice) / (maxPrice - minPrice)) * height
                            var zeroY = height - ((0 - minPrice) / (maxPrice - minPrice)) * height
                            
                            var barHeight = ((p - minPrice) / (maxPrice - minPrice)) * height

                            var x = axisOffset + i * barWidth
                            var y = height - barHeight

                            // tarkista, onko kyseessä nykyinen pylväs
                            var isCurrent = root.plasmoid.configuration.showQuarterly
                                ? (Number(item.hour) === currentHour && Number(item.minute) === currentQuarter)
                                : (Number(item.hour) === currentHour)

                            // väri hintatason mukaan
                            //for (let p of prices) {
                            //    ctx.fillStyle = getColor(p);
                            //    // ctx.fillRect(...);
                            //}
                            if (p < (root.plasmoid.configuration.lowThreshold ?? 8)) ctx.fillStyle = getColor(p) //"#7CFF4C"
                            else if (p < (root.plasmoid.configuration.highThreshold ?? 20)) ctx.fillStyle = getColor(p) //"#4CA6FF"
                            else ctx.fillStyle = getColor(p) // "#FF4C4C"

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
                            
                            // Pylvään piirto
                            if (p >= 0) {
                                // positiivinen → nollasta ylöspäin
                                var barHeight = zeroY - valueY
                                ctx.fillRect(x, valueY, barWidth * 0.8, barHeight)
                            } else {
                                // negatiivinen → nollasta alaspäin
                                var barHeight = valueY - zeroY
                                ctx.fillRect(x, zeroY, barWidth * 0.8, barHeight)
                            }
                            
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

    // Päivitä hinta ja otsikko, kun asetusikkuna suljetaan
    Connections {
        target: plasmoid.configuration
        function onShowQuarterlyChanged() {
            otsikkoText.text = plasmoid.configuration.showQuarterly
                           ? "Sähkön varttihinta"
                           : "Sähkön tuntihinta"
            showPrice()
        }
    }
   
    Component.onCompleted: {
        if (!plasmoid.configuration.lastFetchDate) {
            plasmoid.configuration.lastFetchDate = "1970-01-01T00:00:00.000Z"
        }
        fetchPrices();
        
    }
}
