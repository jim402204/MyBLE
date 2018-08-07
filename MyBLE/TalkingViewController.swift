//
//  TalkingViewController.swift
//  MyBLE
//
//  Created by Jim on 2018/7/5.
//  Copyright © 2018年 Jim. All rights reserved.
//

import UIKit
import CoreBluetooth

class TalkingViewController: UIViewController , CBPeripheralDelegate{

    var talkingCharacteristic : CBCharacteristic!
    var talkingPeripheral : CBPeripheral!
    
    
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var textField: UITextField!
    
    @IBAction func sendBtn(_ sender: UIBarButtonItem) {
        
        guard let input = textField.text , !input.isEmpty  else {
            return  }
        
        textField.resignFirstResponder() //Dismiss key boread
        
        guard let data = "[Jim] \(input)\n".data(using: .utf8) else {
            assertionFailure("Fail to content to data.")
            return  }
        
        // Detect the write type.
        let properties = talkingCharacteristic.properties  //屬性 定義好了
        let type : CBCharacteristicWriteType =
            properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        //三元運算
        
        talkingPeripheral.writeValue(data, for: talkingCharacteristic, type: type)
        //兩種傳輸方式  安全送達 像圖片需解碼withResponse  即時控制命令withoutResponse
        //central 要follow Peripheral 這兩種方式。現在這邊是寫死
//        textView.text = String(data: data, encoding: .utf8)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if talkingCharacteristic == nil {
            assertionFailure("talkingCharacteristic is nil!")
        }
        
        talkingPeripheral = talkingCharacteristic.service.peripheral
        //delegate 可以這樣換嗎   是可以的 中途換delegate
        talkingPeripheral.delegate = self
        talkingPeripheral.setNotifyValue(true, for: talkingCharacteristic)
        
        //Do any additional setup after loading the view.
        //周圍設備 要讀取 發送端 時 最後手段是 polling(輪詢)
        //周圍設備 訂閱（ble規範有的方法） ,中央發送端 有資料要給時 會主動通知周圍設備
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
    }
    
    //Mark Peripheral.delegate Methods
    
    //只要Central 有資料會主動通知
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        guard let data = characteristic.value else {
            assertionFailure("characteristic.value is nil")
            return  }
        
        guard let content = String(data: data, encoding: .utf8) else {
            assertionFailure("Fail to convert data to string")
            return  }
        
        textView.text! += content
        
    }
    
    //peripheral 設定回傳的方式        peripheral 對characteristic設定
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {//方法要這樣看 peripheral  didWriteValueFor characteristic
        
        if let error = error {
            print("didWriteValue error: \(error)")
            return
        }
        print("didWriteValue OK.")
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
