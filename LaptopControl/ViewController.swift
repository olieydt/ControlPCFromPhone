//
//  ViewController.swift
//  LaptopControl
//
//  Created by Oli Eydt on 2018-06-13.
//  Copyright © 2018 BroLoveEnergy. All rights reserved.
//

import UIKit
import SwiftSocket
import CocoaAsyncSocket

class ViewController: UIViewController, GCDAsyncUdpSocketDelegate {

    @IBOutlet var label: UILabel!

    @IBOutlet var connectBtn: UIButton!
    @IBOutlet var backBtn: UIButton!
    @IBAction func backBtnPressed(_ sender: Any) {
        //send disconnect
        switch tcpClient.connect(timeout: 5) {
        case .success:
            let coords: Data = "end".data(using: .utf8)!
            let result = tcpClient.send(data: coords)
            //print(result)
            lastTouchCoordinates = ""
        case .failure(let error):
            lastTouchCoordinates = ""
        }
        if(udpServerSocket != nil && !udpServerSocket.isClosed()){
            udpServerSocket.close()
        }
        if(tcpClient != nil){
            tcpClient.close()
        }
        label.isHidden = true
        connectBtn.isHidden = false
        backBtn.isHidden = true
    }
    @IBAction func connectBtnPressed(_ sender: Any) {
        let privateIp = getWiFiAddress()
        if(privateIp != nil && !privateIp!.isEmpty){
            //multicast ip address
            let ip = "230.0.0.0"
            //let ip = "255.255.255.255"
            do {
                udpServerSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
                try udpServerSocket.bind(toPort: 12345)
                try udpServerSocket.connect(toHost: ip, onPort: 12345)
                udpServerSocket.send(("DEVICEIP:" + getWiFiAddress()!).data(using: .utf8)!, withTimeout: 1000, tag: 0)
                udpServerSocket.closeAfterSending()
                //try socket.enableBroadcast(true)
                //socket.sendData("gros", toHost: address, port: 12345, withTimeout: 1000, tag: 0)
            } catch {
                print(error)
            }
            //let udpClient = UDPClient(address: ip, port: 12345)
            //let _ = udpClient.send(string: "DEVICEIP:" + getWiFiAddress()!)
            //udpClient.close()
            
            //let udpServer = UDPServer(address: "127.0.0.1", port: 12345)
            //let result = udpServer.recv(256)
            //print(result)
        }
    }
    
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?){
        //convert to string
        if let received = String(bytes: data, encoding: .utf8) {
            if(received.contains("PCIP")){
                let addressArray = [UInt8](address)
                let serverIp = "\(addressArray[4]).\(addressArray[5]).\(addressArray[6]).\(addressArray[7])"
                tcpClient = TCPClient(address: serverIp, port: 12347)
                label.isHidden = false
                connectBtn.isHidden = true
                backBtn.isHidden = false
            }
        }
        udpServerSocket.close()
    }
    
    //screen constants
    var tcpClient:TCPClient!
    var udpServerSocket:GCDAsyncUdpSocket!
    //keep in string form to be easily sendable
    var lastTouchCoordinates:String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //add notification for background
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appExit), name: Notification.Name.UIApplicationWillResignActive, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appExit), name: Notification.Name.UIApplicationWillTerminate, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appExit), name: Notification.Name.UIApplicationDidEnterBackground, object: nil)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(singleTap(gesture:)))
        view.addGestureRecognizer(tapGesture)
        
        do {
            udpServerSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
            try udpServerSocket.bind(toPort: 12346)
            try udpServerSocket.beginReceiving()
            
            //try socket.enableBroadcast(true)
            //socket.sendData("gros", toHost: address, port: 12345, withTimeout: 1000, tag: 0)
        } catch {
            print(error)
        }
        lastTouchCoordinates = ""
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @objc func singleTap(gesture: UITapGestureRecognizer) {
        if(connectBtn.isHidden){
            sendCoords(coordsToSend: "click")
        }
    }
    
    @objc func appExit(){
        if(udpServerSocket != nil && !udpServerSocket.isClosed()){
            udpServerSocket.close()
        }
        if(tcpClient != nil){
            tcpClient.close()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if(connectBtn.isHidden){
            if let touch = touches.first {
                let position = touch.location(in: self.view)
                addCoordinate(point: position)
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if(connectBtn.isHidden){
            if let touch = touches.first {
                let position = touch.location(in: self.view)
                addCoordinate(point: position)
            }
            sendCoords(coordsToSend: lastTouchCoordinates)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if(connectBtn.isHidden){
            if let touch = touches.first {
                let position = touch.location(in: self.view)
                addCoordinate(point: position)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    func sendCoords(coordsToSend: String){
        if(coordsToSend.isEmpty || (coordsToSend != "click" && coordsToSend.components(separatedBy: ",").count < 2)){
            return
        }
        /*var coordsToSend = coordsToSend
        let coordsArray = coordsToSend.components(separatedBy: ",")
        let firstCoord = coordsArray[0].components(separatedBy: ":")
        let secondCoord = coordsArray[1].components(separatedBy: ":")
        if(coordsArray.count == 2 && firstCoord[0] == secondCoord[0] && firstCoord[1] == secondCoord[1]){
            coordsToSend = "click"
        }*/
        switch tcpClient.connect(timeout: 5) {
        case .success:
            let coords: Data = coordsToSend.data(using: .utf8)!
            let result = tcpClient.send(data: coords)
            //print(result)
            lastTouchCoordinates = ""
        case .failure(let error):
            lastTouchCoordinates = ""
        }
    }
    
    func addCoordinate(point: CGPoint){
        //var point = CGPoint(x: point.x/screenWidth, y: point.y/screenHeight)
        let formatPoint = "\(point.x):\(point.y)"
        
        lastTouchCoordinates = lastTouchCoordinates.isEmpty ? formatPoint : lastTouchCoordinates + "," + formatPoint
        if(lastTouchCoordinates.components(separatedBy: ",").count >= 8){
            sendCoords(coordsToSend: lastTouchCoordinates)
        }
    }
    
    // Return IP address of WiFi interface (en0) as a String, or `nil`
    func getWiFiAddress() -> String? {
        var address : String?
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check for IPv4 or IPv6 interface:
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                
                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if  name == "en0" {
                    
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
        
        return address
    }

}

