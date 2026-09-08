import CoreWLAN

let client = CWWiFiClient.shared()

if let interface = client.interface(), interface.powerOn() {
    let rssi = interface.rssiValue()

    if rssi >= 0 {
        print("offline")
    } else {
        print("connected|\(rssi)")
    }
} else {
    print("offline")
}
