import UIKit
import CoreBluetooth

class ViewController: UIViewController {
    
    private var centralManager: CBCentralManager!
    private var tableView: UITableView!
    private var bluetoothDevices: [CBPeripheral] = []
    private var selectedPeripheral: CBPeripheral?
    
    var discoveredServices: [CBService] = []
    
    var charvalue: Data!
    
    let hexString = "4D54363041453534423033374351303031000000000000000000000000000000000001011E000100010C01004100000000000000413733303050312D45320000000000002D"
    
//    let heartRateServiceCBUUID = CBUUID(string: "0x180D")
//    
//    let heartRateMeasurementCharacteristicCBUUID = CBUUID(string: "2A37")
//    let bodySensorLocationCharacteristicCBUUID = CBUUID(string: "2A38")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("Hex to string",hexToString(hexString) as Any)
        // Initialize the central manager
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // Create the table view
        tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    func generateHapticFeedback() {
        let impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedbackGenerator.prepare()
        impactFeedbackGenerator.impactOccurred()
    }
    
    func hexToString(_ hex: String) -> String? {
        var hex = hex
        var string = ""
        
        while hex.count > 0 {
            let index = hex.index(hex.startIndex, offsetBy: 2)
            let hexByte = String(hex[..<index])
            hex = String(hex[index...])
            
            if let num = UInt8(hexByte, radix: 16) {
                string.append(Character(UnicodeScalar(num)))
            } else {
                // Invalid hex string
                return nil
            }
        }
        
        return string
    }
    
}


extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bluetoothDevices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "BluetoothCell")
        
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: "BluetoothCell")
        }
        
        let peripheral = bluetoothDevices[indexPath.row]
        
        if let name = peripheral.name {
            cell?.textLabel?.text = name
        } else {
            cell?.textLabel?.text = "Unknown Device"
        }
        
        cell?.detailTextLabel?.text = peripheral.identifier.uuidString
        
        return cell!
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        centralManager.stopScan()
        selectedPeripheral = bluetoothDevices[indexPath.row]
        centralManager.connect(selectedPeripheral!, options: nil)
    }
}

extension ViewController: CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate {
    
    
    // MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            print("Services discovered for \(peripheral.name ?? "Unknown Device"):")
            for service in services {
                print("Service UUID: \(service.uuid)")
                discoveredServices.append(service)
            }
            print("discoveredServices: ", discoveredServices)
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            print("Service: ",service)
            print("service.characteristics: ",service.characteristics ?? "characteristics are nil")
            peripheral.discoverCharacteristics(nil, for: service)
        }
        
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            print("didDiscoverCharacteristicsFor: ",characteristic)
            
            if characteristic.properties.contains(.read) {
                print("\(characteristic.uuid): properties contains .read")
                peripheral.readValue(for: characteristic)
                
            }
            
            if characteristic.properties.contains(.notify) {
                print("\(characteristic.uuid): properties contains .notify")
                peripheral.setNotifyValue(true, for: characteristic)
                print("Notified successfully")
                generateHapticFeedback()
            }
            
            if characteristic.properties.contains(.write) {
                print("\(characteristic.uuid): properties contains .write")
//                let dataString = "hello world 123"
//                if let data = dataString.data(using: .utf8) {
//                    // Use the 'data' object as needed
//                    print(data)
//                    peripheral.writeValue(data, for: characteristic, type: .withResponse)
//                } else {
//                    print("Unable to convert the string to data.")
//                }
                
                let hexString = "4D54363041453534423033374351303031000000000000000000000000000000000001011E000100010C01004100000000000000413733303050312D45320000000000002D"
                if let data = hexString.data(using: .hexadecimal) {
                    peripheral.writeValue(data, for: characteristic, type: .withResponse)
                    charvalue = characteristic.value
                    print("Data written successfully.")
                } else {
                    print("Unable to convert the hex string to data.")
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error reading characteristic value: \(error.localizedDescription)")
            return
        }
        if characteristic.value! as NSObject == CBUUID.init(string: "C304") {
            if let value = characteristic.value {
                let stringValue = String(data: value, encoding: .utf8)
                print("Read value for \(characteristic.uuid.uuidString): \(stringValue ?? "Unable to convert data to string")")
            } else {
                print("No data received for characteristic \(characteristic.uuid.uuidString)")
            }
        }
    }

    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Discover services when connected to a peripheral
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        print("Connected!")
        //selectedPeripheral?.discoverServices([heartRateServiceCBUUID])
        selectedPeripheral?.discoverServices(nil)
    }
    
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            // Start scanning for Bluetooth devices
            print("Start scanning for Bluetooth devices")
//            centralManager.scanForPeripherals(withServices: [heartRateServiceCBUUID], options: nil)
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            // Handle Bluetooth not available or powered off
            print("Bluetooth is not available or powered off.")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Add the discovered peripheral to the array
        if !bluetoothDevices.contains(peripheral) {
            bluetoothDevices.append(peripheral)
            tableView.reloadData()
            print("--------------------------------------")
            print("peripheral devices: ", bluetoothDevices)
            print("advertisementData: ", advertisementData.description)
            print("--------------------------------------")
        }
        
//        print("found peripheral: \(peripheral)")
//        selectedPeripheral = peripheral
//        selectedPeripheral?.delegate = self
//        centralManager.stopScan()
//        centralManager.connect(selectedPeripheral!)
    }
    
    // MARK: - CBPeripheralManagerDelegate
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("peripheralManagerDidUpdateState", peripheral.isAdvertising)
    }
    
}


extension String {
    func hexToData() -> Data? {
        var hex = self
        var data = Data()
        
        while hex.count > 0 {
            let index = hex.index(hex.startIndex, offsetBy: 2)
            let byte = String(hex[..<index])
            hex = String(hex[index...])
            
            if var num = UInt8(byte, radix: 16) {
                data.append(&num, count: 1)
            } else {
                print("Invalid hex string.")
                return nil
            }
        }
        
        return data
    }
}

extension String.Encoding {
    static var hexadecimal: String.Encoding {
        return String.Encoding(rawValue: 30)
    }
}
