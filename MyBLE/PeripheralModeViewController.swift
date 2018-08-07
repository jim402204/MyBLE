

import UIKit
import CoreBluetooth

class PeripheralModeViewController: UIViewController ,CBPeripheralManagerDelegate{
    
    var manager: CBPeripheralManager!
    var mainCharacteristic : CBMutableCharacteristic?
    var resnedBuffer = ""
    
    
    let serviceUUID = CBUUID(string: "8886") //測試用
    let characterUUID = CBUUID(string: "8888") //要跟前面一樣
    let chatroomName = "Jim聊天室"
    
    
    
    @IBOutlet weak var inputTextField: UITextField!
    @IBOutlet weak var logTextView: UITextView!
    
    @IBAction func snedBtnPressed(_ sender: UIBarButtonItem) {
        
        guard let input = inputTextField.text, !input.isEmpty else {
            return  }
        inputTextField.resignFirstResponder()
        
        let message = "[\(chatroomName)] \(input)\n"
        
        logTextView.text! += message
        
        sendMessage(message, central: nil)
    }
    
    @IBAction func enableValueChanged(_ sender: UISwitch) {
        
        if sender.isOn {
            startToAdvertise()
        } else {
            stopAdvertising()
        }
    }
    
    
    
    
    func startToAdvertise()  {
        //..
        if mainCharacteristic == nil{
            let properties : CBCharacteristicProperties = [.notify, .read, .write]
            let permissions : CBAttributePermissions = [.readable , .writeable]

            mainCharacteristic = CBMutableCharacteristic(type: characterUUID, properties: properties, value: nil, permissions: permissions)

            let servie = CBMutableService(type: serviceUUID , primary: true)
            servie.characteristics = [mainCharacteristic!]
            //同一個裝置可容納多個功能characteristics
            manager.add(servie) //附加
        }
        
        let UUIDs = [serviceUUID] //impoertant! it must be a array
        let info :[String: Any] = [CBAdvertisementDataLocalNameKey: chatroomName,CBAdvertisementDataServiceUUIDsKey: UUIDs]
        manager.startAdvertising(info)      //開始廣播
    }
    //Start to Advertise
    func stopAdvertising()  {
        manager.stopAdvertising()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        manager = CBPeripheralManager(delegate: self, queue: nil)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    //
    func sendMessage(_ message: String,central: CBCentral?)  {
        //...
        let centrals = (central == nil ? nil : [central!])
        
        guard let data = message.data(using: .utf8) else {
            assertionFailure("Fail to convert string to data")
            return  }
        
        guard let characteristic = mainCharacteristic else {
            assertionFailure("mainCharacteristic is nil")
            return  }
        
        let success = manager.updateValue(data, for: characteristic, onSubscribedCentrals: centrals)
        //updateValue傳送          傳輸的queue 滿了 會回傳false      頻率是太近 指的是發送指令
        
        // Keep message in resendBuffer and wait to send it latter.
        if success == false {
            resnedBuffer += message
        }
        
    }
    
    
    // MARK: - CBPeripheralManagerDelegate Methods
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        //...   偵測藍芽狀態
    }
    //peripheral 模擬成某設備 發廣播
    
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {//有人連上  可以同時讓多人連上自己
        
        guard let total = mainCharacteristic?.subscribedCentrals?.count else {
            assertionFailure("Fail to get toatal count of subscribedCentrals")
            return  }
        //message 發給所有人
        let message = "* Some comeing! \(central.identifier),max update lenth: \(central.maximumUpdateValueLength).\n" //central.identifier 唯一識別
        //central.maximumUpdateValueLength 一次封包 最長是多少
        //發給連上的那個人
        let hello = "* Welocme to \(chatroomName).(Total:\(total))\n"
        
        
        // Show messae at logTextView.
        logTextView.text! += message
        
        
        //這邊是連續發送
        // Send to the central only that just subscribed.  //連上的那個人
        sendMessage(hello, central: central)
        
        // Send to all centrals.  //發給所有人
        sendMessage(message, central: nil)
        
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        let message = "* Someone leaving! \(central.identifier).\n"
        
        logTextView.text! += message
        sendMessage(message, central: nil)
    }
    
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        
        for requset in requests{
            guard let value = requset.value else{   //不管成功失敗都會給回應
                manager.respond(to: requset, withResult: .invalidAttributeValueLength)
                continue
            }
            
            guard let message = String(data: value, encoding: .utf8) else {
                manager.respond(to: requset, withResult: .requestNotSupported)
                return  }
            
            logTextView.text! += message
            sendMessage(message, central: nil)  //Foward to all
            manager.respond(to: requset, withResult: .success)
        }
        
        
    }
    
    // note! this method will be execute only when manager.updateValues() -> false
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        //Resnd resnedBuffer content to all.
        sendMessage(resnedBuffer, central: nil) //重新發送
        resnedBuffer = ""
    }
    
    
}

