import Foundation
import CoreBluetooth

class MainScene
: CCNode
, CBCentralManagerDelegate // for central
, CBPeripheralDelegate // for central
, CBPeripheralManagerDelegate // for peripheral
{
    var count: UInt8 = 1

    var _label: CCLabelTTF!

    // for central
    var centralManager: CBCentralManager!

    // for peripheral
    var peripheralManager: CBPeripheralManager!
    var serviceUUID: CBUUID!
    var characteristic: CBMutableCharacteristic!

    override func onEnter() {
        super.onEnter()
        self.userInteractionEnabled = true
        println("onEnter")

        // initialize central
        self.centralManager = CBCentralManager(delegate: self, queue: nil)

        // initialize peripheral
        self.peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: nil)

        _label.string = String(count)
    }

    override func  onExit() {
        super.onExit()
        println("onExit")
    }

    override func touchBegan(touch:CCTouch!, withEvent event:CCTouchEvent!) {
        println("touchBegan")
        count = count + 1

        _label.string = String(count)

        // 新しい値となるNSDataオブジェクトを生成
        let data = NSData(bytes: [count] as [UInt8], length: 1)

        // 値を更新
        self.characteristic.value = data;

        let result =  self.peripheralManager.updateValue(
            data,
            forCharacteristic: self.characteristic,
            onSubscribedCentrals: nil)
    }

    // =========================================================================
    // CBCentralManagerDelegate
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        println("centralManagerDidUpdateState")
        switch central.state {

        case CBCentralManagerState.PoweredOn:
            // スキャン開始
            println("スキャン開始")
            centralManager.scanForPeripheralsWithServices([CBUUID(string: "0000")], options: nil)
            break

        default:
            break
        }
    }

    func centralManager(central: CBCentralManager!,
        didDiscoverPeripheral peripheral:CBPeripheral!,
        advertisementData: [NSObject : AnyObject]!,
        RSSI:NSNumber!) {

        // スキャン結果受取
        println("スキャン結果受取 \(peripheral)")

        // 接続開始
        self.centralManager.connectPeripheral(peripheral, options: nil)
    }

    func centralManager(central: CBCentralManager!,
        didConnectPeripheral peripheral: CBPeripheral!) {
        println("接続成功！ \(peripheral)")

        peripheral.delegate = self;

        // サービス探索開始
        peripheral.discoverServices(nil)
    }

    func centralManager(central: CBCentralManager!,
        didFailToConnectPeripheral peripheral: CBPeripheral!,
        error: NSError!) {

        println("接続失敗・・・")
    }

    func centralManager(central: CBCentralManager!,
        didDisconnectPeripheral peripheral: CBPeripheral!,
        error: NSError!) {

        println("接続が切断されました。")
    }

    // =========================================================================
    // CBPeripheralDelegate

    // サービス発見時に呼ばれる
    func peripheral(peripheral: CBPeripheral!, didDiscoverServices error:NSError!) {


        let services = peripheral.services;
        println("Found \(services.count) services! :\(services)")


        for service in services {
            // キャラクタリスティック探索開始
            peripheral.discoverCharacteristics(nil, forService: service as! CBService)
        }
    }

    // キャラクタリスティック発見時に呼ばれる
    func peripheral(peripheral: CBPeripheral!,
        didDiscoverCharacteristicsForService service: CBService!,
        error: NSError!) {
        let characteristics = service.characteristics
        println("Found \(characteristics.count) characteristics! : \(characteristics)")

        for c in characteristics {
            peripheral.setNotifyValue(true, forCharacteristic: c as! CBCharacteristic)
        }
    }

    // Notify開始／停止時に呼ばれる
    func peripheral(peripheral: CBPeripheral!,
        didUpdateNotificationStateForCharacteristic characteristic:CBCharacteristic!,
        error: NSError!) {
        if error != nil {
            println("Notify状態更新失敗...error: \(error)")
        }
        else {
            println("Notify状態更新成功！ isNotifying: \(characteristic.isNotifying)")
        }
    }


    // データ更新時に呼ばれる
    func peripheral(peripheral: CBPeripheral!,
        didUpdateValueForCharacteristic characteristic: CBCharacteristic!,
        error:NSError!)
    {
        if error != nil {
            println("データ更新通知エラー: \(error)")
            return
        }

        println("データ更新！ characteristic UUID: \(characteristic.UUID), value: \(characteristic.value)")


        // TODO: 更新
        let data = characteristic.value
        println("\(data)")

    }

    func peripheral(peripheral: CBPeripheral!,
        didWriteValueForCharacteristic characteristic:CBCharacteristic!,
        error: NSError!)
    {
        if (error != nil) {
            println("Write失敗...error: \(error)")
            return
        }

        println("Write成功！")
    }



    // =========================================================================
    // MARK: Private

    func publishservice () {

        // サービスを作成
        self.serviceUUID = CBUUID(string: "0000")
        let service = CBMutableService(type: serviceUUID, primary: true)

        // キャラクタリスティックを作成
        let characteristicUUID = CBUUID(string: "0001")

        let properties = (
            CBCharacteristicProperties.Notify |
                CBCharacteristicProperties.Read |
                CBCharacteristicProperties.Write)

        let permissions = (
            CBAttributePermissions.Readable |
                CBAttributePermissions.Writeable)

        self.characteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: properties,
            value: nil,
            permissions: permissions)

        // キャラクタリスティックをサービスにセット
        service.characteristics = [self.characteristic]

        // サービスを Peripheral Manager にセット
        self.peripheralManager.addService(service)

        // 値をセット
        let value: UInt8 = UInt8(arc4random() & 0xFF)
        let data = NSData(bytes: [value] as [UInt8], length: 1)
        self.characteristic.value = data;
    }

    func startAdvertise() {

        // アドバタイズメントデータを作成する
        let advertisementData: Dictionary = [
            CBAdvertisementDataLocalNameKey: "Test Device",
            CBAdvertisementDataServiceUUIDsKey: [self.serviceUUID]
        ]

        // アドバタイズ開始
        self.peripheralManager.startAdvertising(advertisementData)

        println("STOP ADVERTISING")
    }

    func stopAdvertise () {

        // アドバタイズ停止
        self.peripheralManager.stopAdvertising()

        println("START ADVERTISING")
    }

    // =========================================================================
    // MARK: CBPeripheralManagerDelegate

    // ペリフェラルマネージャの状態が変化すると呼ばれる
    func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager!) {

        println("state: \(peripheral.state)")

        switch peripheral.state {

        case CBPeripheralManagerState.PoweredOn:
            // サービス登録開始
            self.publishservice()
            break

        default:
            break
        }
    }

    // サービス追加処理が完了すると呼ばれる
    func peripheralManager(peripheral: CBPeripheralManager!, didAddService service: CBService!, error: NSError!) {

        if (error != nil) {
            println("サービス追加失敗！ error: \(error)")
            return
        }

        println("サービス追加成功！")

        // アドバタイズ開始
        self.startAdvertise()
    }

    // アドバタイズ開始処理が完了すると呼ばれる
    func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager!, error: NSError!) {

        if (error != nil) {
            println("アドバタイズ開始失敗！ error: \(error)")
            return
        }

        println("アドバタイズ開始成功！")
    }

    // Readリクエスト受信時に呼ばれる
    func peripheralManager(peripheral: CBPeripheralManager!, didReceiveReadRequest request: CBATTRequest!) {

        println("Readリクエスト受信！ requested service uuid:\(request.characteristic.service.UUID) characteristic uuid:\(request.characteristic.UUID) value:\(request.characteristic.value)")

        // プロパティで保持しているキャラクタリスティックへのReadリクエストかどうかを判定
        if request.characteristic.UUID.isEqual(self.characteristic.UUID) {

            // CBMutableCharacteristicのvalueをCBATTRequestのvalueにセット
            request.value = self.characteristic.value;

            // リクエストに応答
            self.peripheralManager.respondToRequest(request, withResult: CBATTError.Success)
        }
    }

    // Writeリクエスト受信時に呼ばれる
    func peripheralManager(peripheral: CBPeripheralManager!, didReceiveWriteRequests requests: [AnyObject]!) {

        println("\(requests.count) 件のWriteリクエストを受信！")

        for obj in requests {

            if let request = obj as? CBATTRequest {

                println("Requested value:\(request.value) service uuid:\(request.characteristic.service.UUID) characteristic uuid:\(request.characteristic.UUID)")

                if request.characteristic.UUID.isEqual(self.characteristic.UUID) {

                    // CBCharacteristicのvalueに、CBATTRequestのvalueをセット
                    self.characteristic.value = request.value;
                }
            }
        }

        // リクエストに応答
        self.peripheralManager.respondToRequest(requests[0] as! CBATTRequest, withResult: CBATTError.Success)
    }

    // Notify開始リクエスト受信時に呼ばれる
    func peripheralManager(peripheral: CBPeripheralManager!, central: CBCentral!, didSubscribeToCharacteristic characteristic: CBCharacteristic!)
    {
        println("Notify開始リクエストを受信")
        println("Notify中のセントラル: \(self.characteristic.subscribedCentrals)")
    }

    // Notify停止リクエスト受信時に呼ばれる
    func peripheralManager(peripheral: CBPeripheralManager!, central: CBCentral!, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic!)
    {
        println("Notify停止リクエストを受信")
        println("Notify中のセントラル: \(self.characteristic.subscribedCentrals)")
    }


}
