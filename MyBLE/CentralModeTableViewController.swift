

import UIKit
import CoreBluetooth


class CentralModeTableViewController: UITableViewController , CBCentralManagerDelegate , CBPeripheralDelegate{
    
    var manager : CBCentralManager!
    var foundItem = [String: DiscoverItem]()
    var lastReloadDate = Date()     //用啟動時間 省去可選型別
    
    var restServices = [CBService]()
    var info = ""
    
//    let targetUUIDString = "FFE1"     //藍芽聊天
//    let targetUUIDString = "DFB1"
    let targetUUIDString = "8888"
    var shouldtaking = false
    
    var talkingCharacteristic : CBCharacteristic?  //藍牙的功能
    
    
    
    @IBAction func scanEableValueCgange(_ sender: UISwitch) {
        if sender.isOn {
            startToScan()
        } else {
            stopScanning()
        }
        //細節錯誤處理 都還沒寫 是否還在聯繫..等等
    }
    
    func startToScan()  {
        //什麼是ＵＵＩＤ 唯一識別碼 本身並沒有中央端去控管 32bit 8 4 4 4 12組成
        // 短版與長版的UUID 不相容 真實產品必須長版
        let options = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        //允許重複 回報給App   預設false 只收到第一次
//        let servies = [CBUUID(string: "1234"), CBUUID(string: "ABCD")]
        //withServices: nil 不指定掃描誰（）
        
        let servies = [CBUUID(string: "8886")]
        manager.scanForPeripherals(withServices: servies, options: options)//設定好就開始了
    }
    
    func stopScanning(){
        manager.stopScan()
    }
    
    override func viewDidAppear(_ animated: Bool) {//會用在我talking回來
        super.viewDidAppear(true)//
        
        // Disconnecnt when return from TalkingVC
        if let characteristic = talkingCharacteristic{//talkingCharacteristic是否存在
            
            let periphal = characteristic.service.peripheral
            if periphal.state == .connected {//在talk時 已經斷線 在下達cancel會閃退
                manager.cancelPeripheralConnection(periphal)
            }
            talkingCharacteristic = nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        manager = CBCentralManager(delegate: self, queue: nil)
        //queue: nil 用main queue 一般都指定在背景做 (他回傳會在 呼叫的queue)
        //或是在背景做 需要再背景去接 回傳的資料 並拉回主執行緒
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return foundItem.count //這是字典
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        //字典沒順序性 有唯一性 字典的key有順序性
        
        // Configure the cell
        guard let item = discoveredItem(at: indexPath) else {
            assertionFailure("Fail to get discoveredI")
            return  cell}
        
        let name = item.peripheral.name ?? "(NoName)"
        cell.textLabel?.text = "\(name) RSSI: \(item.rssi)"
        let timeIntervalString = String(format: "%.1f", Date().timeIntervalSince(item.lastSeenDate))
        cell.detailTextLabel?.text = "Last seen: \(timeIntervalString) second ago."
        
        return cell
    }
    
    func discoveredItem(at: IndexPath) -> DiscoverItem? {
        let allKeys = Array(foundItem.keys)
        let targetKey = allKeys[at.row]
        
        return foundItem[targetKey]
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = discoveredItem(at: indexPath) else {
            assertionFailure("Fail to get discoveredI")
            return  }
        shouldtaking = true
        manager.connect(item.peripheral, options: nil)
    }
    //點選accessoryButton
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        guard let item = discoveredItem(at: indexPath) else {
            assertionFailure("Fail to get discoveredI")
            return  }
        shouldtaking = false
        manager.connect(item.peripheral, options: nil)
        //藍芽 可能會等到好幾秒 10s    無線訊號的不穩定 所以錯誤處理要很嚴謹 一上蓋 訊號就很弱了
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let talkingVC = segue.destination as? TalkingViewController else {
            assertionFailure("Invalid talkingVC class type.")
            return  }
        talkingVC.talkingCharacteristic = talkingCharacteristic
        
    }
    
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("didConnect: \(peripheral.identifier)")
        stopScanning()
        
        // Discover service of peripheral.
        peripheral.delegate = self
        peripheral.discoverServices(nil)    //用nil會回報所有的 用特定的uuid 省電
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("didDisconnectPeripheral: \(peripheral.identifier)")
        startToScan()
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        //交握失敗 訊號不好失敗   BLE 沒有timeout（時間到不等消息）
        //timeout 要自己實作 定計時然後 傳不連線
        
        print("didFailToConnect: \(error?.localizedDescription ?? "UNknow" )")
        
    }
    
    //Mark - CBPeripherelDelegate Methods.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        //可以用retry 幾次才真正失敗
        
        if let error = error {
            showAlert("didDiscoverServices fail: \(error)")
            manager.cancelPeripheralConnection(peripheral) //Disconnect
            //會觸發didDisconnectPeripheral
            return
        }
//        peripheral.services
        
        //        guard let services = peripheral.services else {
        //            assertionFailure("peripheral.services should not be nil.")
        //            manager.cancelPeripheralConnection(peripheral)
        //            return  }
        //        restServices = services
        //        handleNextService(of: peripheral)
        //
        //        info = "* Peripheral: \(peripheral.name ?? "NoName") (\(services.count)services)\n"

        
        guard let services = peripheral.services else {
            assertionFailure("peripheral.services should not be nil")
            manager.cancelPeripheralConnection(peripheral)
            return  }
        restServices = services
        handleNextService(of: peripheral)
        info = "* peripheral: \(peripheral.name ?? "NoName") \(services.count)services)\n"
    }
    
    
    
   
    
    func showAlert(_ message:String)  {
        
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert )
        let ok = UIAlertAction(title: "OK", style: .default)
        
        alert.addAction(ok)
        present(alert,animated: true)
        
    }
    
    //Mask - CBCentralManagerDelegate.
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        let state = central.state
        if state != .poweredOn {
            // Show error message.
            let message = "BLE is not available. error:\(state.rawValue)"
            showAlert(message)
            //...
        }
        
        
    }//藍牙狀態有改變時 動作
    
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        
//        print("Discovered: \(peripheral.name ?? "NoName") , RSSI: \(RSSI),identifier: \(peripheral.identifier.uuidString) , advertisementData: \(advertisementData)")
        //peripheral.identifier.uuidString 只有在這個app才有效
        //只要是叫identifier 是都開發者 或系統造的假資料
        
        let identifier = peripheral.identifier.uuidString
        let existItem = foundItem[identifier]
        if existItem == nil{
            // Show info only at the time receive advertisment.
            print("Discovered: \(peripheral.name ?? "NoName") , RSSI: \(RSSI),identifier: \(peripheral.identifier.uuidString) , advertisementData: \(advertisementData)")
        }
        
        let now = Date()
        let newItem = DiscoverItem(peripheral: peripheral, rssi: RSSI.intValue, lastSeenDate: now)
        
        foundItem[identifier] = newItem //Update to foundItem.
        
        // Check if we should reload date now.
        if existItem  == nil || now.timeIntervalSince(lastReloadDate) > 2.0{
            self.tableView.reloadData()
            lastReloadDate = now
        }

    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            showAlert("didDiscoverCharacteristics fail: \(error)")
            manager.cancelPeripheralConnection(peripheral) //Disconnect
            //會觸發didDisconnectPeripheral
            return
        }
        
        guard let characteristics = service.characteristics else {
            assertionFailure("service.characteristics should not be nil.")
            manager.cancelPeripheralConnection(peripheral)
            return  }
        
        info += "* Service: \(service.uuid.uuidString)(\(characteristics.count)char.)\n"
        
        for tmp in characteristics{
            info += "* Char.: \(tmp.uuid.uuidString)\n"
            
            //If shouldTaking , then check if this what we are looking for
            if shouldtaking , tmp.uuid.uuidString == targetUUIDString{
                talkingCharacteristic = tmp
                performSegue(withIdentifier: "goTalking", sender: nil)
                return //Important
            }
            
        }
        
        //move to next service?
        if restServices.count > 0 {
            handleNextService(of: peripheral)
        } else {
            //Show result to user.
            showAlert(info)
            manager.cancelPeripheralConnection(peripheral)
        }
        
    }
    
    // Mark: - Hepler method.
    func handleNextService(of peripheral: CBPeripheral)  {
        guard let service = restServices.first else {
            return  }
        restServices.removeFirst()
        
        peripheral.discoverCharacteristics(nil, for: service)//這個server下有哪些特點
        
    }
    
    

}

struct DiscoverItem {
    
    let peripheral : CBPeripheral
    let rssi : Int
    let lastSeenDate : Date
}





