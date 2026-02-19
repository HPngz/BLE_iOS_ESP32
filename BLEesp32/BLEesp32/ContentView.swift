//  主界面 - 显示蓝牙设备列表和数据收发
// Main Interface - Displays the list of Bluetooth devices and data transmission and reception

import SwiftUI
import CoreBluetooth

/// 主界面视图 Main interface view
struct ContentView: View {
    // @StateObject 创建并持有 BLE 管理器 Create and hold a BLE manager
    @StateObject private var ble = BLEManager()
    
    // @State 存储要发送的消息（用户输入的文本） Store the message to be sent (the text input by the user)
    @State private var messageToSend = ""
    
    var body: some View {
        NavigationStack {
            // List
            List {
                // 状态区域（蓝牙状态、扫描按钮）Status area (Bluetooth status, scan button)
                statusSection
                
                // 只有在已连接时才显示发送/接收区域 The send/receive area is displayed only when it is connected
                if case .connected = ble.connectionState {
                    sendReceiveSection    // 发送接收区域 Sending and receiving area
                    servicesSection       // 服务和特征列表 List of services and features
                }
                
                // 设备列表区域 Equipment list area
                deviceListSection
            }
            .navigationTitle("ESP32 BLE")  // 顶部标题 Top title
            .toolbar {
                // 只有在已连接时才显示断开按钮 The disconnect button is only displayed when the connection is established
                if case .connected = ble.connectionState {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Disconnect", role: .destructive) {
                            ble.disconnect()  // 断开连接
                        }
                    }
                }
            }
        }
    }
    
    // 状态区域 Status area
    /// 显示蓝牙连接状态和扫描按钮 Display the Bluetooth connection status and the scan button
    private var statusSection: some View {
        Section {
            HStack {
                // 显示连接状态文字 Display the connection status text
                Text(ble.connectionStateText)
                    .foregroundStyle(ble.connectionStateColor)  // 根据状态改变颜色 Change the color according to the status
                
                Spacer()
                
                // 扫描时显示转圈加载动画 A circular loading animation is displayed during scanning
                if ble.isScanning {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                // 扫描/停止扫描按钮
                Button(ble.isScanning ? "Stop Scan" : "Scan Device") {
                    if ble.isScanning {
                        ble.stopScanning()
                    }
                    else {
                        ble.startScanning()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            
            // 错误信息 Error message
            if let err = ble.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Status")
        }
    }
    
    //发送接收区域 Sending and receiving area
    private var sendReceiveSection: some View {
        Section("Send / Receive") {
            // 接收数据窗口 Receiving Data window
            ReceivedDisplayWindow(ble: ble)
            
            // 输入要发送的消息 Enter the message to be sent
            TextField("Message to send...", text: $messageToSend, axis: .vertical)
                .lineLimit(3...6)  // 限制 3-6 行，超过会滚动 Limit 3 to 6 lines. Beyond this limit, scrolling will occur
            
            // 发送按钮 Send message button
            Button("Send") {
                ble.send(messageToSend)
                messageToSend = ""
            }
            .disabled(messageToSend.isEmpty)
            
            // 如果有接收到的数据，显示完整历史记录
            if !ble.receivedText.isEmpty {
                ReceivedRecordView(ble: ble)
            }
        }
    }
    
    //服务和特征区域 Service and feature areas
    private var servicesSection: some View {
        Section {
            // 遍历所有服务
            ForEach(ble.services, id: \.uuid) { svc in
                // DisclosureGroup 可展开/折叠的组
                DisclosureGroup(svc.uuid.uuidString) {
                    ForEach(svc.characteristics ?? [], id: \.uuid) { char in
                        CharacteristicRow(characteristic: char, ble: ble)
                    }
                }
            }
        } header: {
            Text("Services and Characteristics")
        } footer: {
            Text("The app will automatically subscribe to notifications when connected")
                .font(.caption)
        }
    }
    
    // 设备列表区域 Device List area
    private var deviceListSection: some View {
        Section {
            if ble.discoveredDevices.isEmpty && !ble.isScanning {
                Text("Tap 'Scan Device' to find ESP32")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            ForEach(ble.discoveredDevices) { device in
                DeviceRow(device: device, ble: ble)
            }
        } header: {
            Text("Nearby Devices")
        }
    }
}

// 数据接收窗口组件 Data Receiving area
/// 显示从 ESP32 接收到的数据
struct ReceivedDisplayWindow: View {
    // @ObservedObject 监听 BLE 管理器的变化 Listen for changes in the BLE manager
    @ObservedObject var ble: BLEManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Received Data")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                
                if !ble.lastReceivedValue.isEmpty {
                    Text("Latest: \(ble.lastReceivedValue)")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            
            // 数据显示框 Data display box
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                
                // 显示的文本内容 The displayed text content
                Text(ble.receivedText.isEmpty ? "Waiting for data from ESP32..." : ble.receivedText)
                    .font(.system(.body, design: .monospaced))
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(12)
                    .textSelection(.enabled)
                    .foregroundStyle(ble.receivedText.isEmpty ? .secondary : .primary)
            }
            .frame(minHeight: 72, maxHeight: 160)
        }
    }
}

//完整历史记录组件 Full History area
/// 显示所有接收到的数据历史 Display the history of all received data
struct ReceivedRecordView: View {
    @ObservedObject var ble: BLEManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Full History")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                
                // Clear button
                Button("Clear") {
                    ble.clearReceived()
                }
                    .font(.caption)
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    Text(ble.receivedText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("bottom")
                }
                .frame(maxHeight: 140)
                
                
                .onChange(of: ble.receivedText) { _, _ in
                    // 有新数据时，自动滚动到底部 When new data is available, it automatically scrolls to the bottom
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }
}

// 设备行组件Equipment row components
struct DeviceRow: View {
    let device: BLEDevice        // 设备信息 Device information
    @ObservedObject var ble: BLEManager
    
    var body: some View {
        Button {
            ble.connect(to: device)  // 连接 Connect
        } label: {
            HStack {
                // 左侧：设备名称和信号强度 On the left: Device name and signal strength
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Signal: \(device.rssi) dBm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 右侧：如果是当前连接的设备，显示绿色勾 On the right: If it is the currently connected device, a green checkmark will be displayed
                if ble.connectedPeripheral?.identifier == device.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(ble.isConnecting)
    }
}

//BLEManager 扩展（提供显示用的文本和颜色）BLEManager Extension (providing text and color for display)
extension BLEManager {
    /// 连接状态对应的文本 The text corresponding to the connection status
    var connectionStateText: String {
        switch connectionState {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .failed(let msg): return "Failed: \(msg)"
        }
    }
    
    /// 连接状态对应的颜色 The color corresponding to the connection status
    var connectionStateColor: Color {
        switch connectionState {
        case .disconnected: return .secondary
        case .connecting: return .orange
        case .connected: return .green
        case .failed: return .red
        }
    }
}

// 特征行组件 Feature row component
/// 显示单个蓝牙特征（Characteristic）的信息和操作按钮
struct CharacteristicRow: View {
    let characteristic: CBCharacteristic
    @ObservedObject var ble: BLEManager
    
    private var props: String {
        var p: [String] = []
        if characteristic.properties.contains(.read) { p.append("Read") }
        if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
            p.append("Write")
        }
        if characteristic.properties.contains(.notify) { p.append("Notify") }
        if characteristic.properties.contains(.indicate) { p.append("Indicate") }
        return p.isEmpty ? "None" : p.joined(separator: ", ")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // UUID
            Text(characteristic.uuid.uuidString)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("Properties: \(props)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 10) {
                if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                    Button {
                        ble.subscribeToNotifications(for: characteristic)
                    } label: {
                        Label("Subscribe", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                    Button {
                        ble.setWriteCharacteristic(characteristic)
                    } label: {
                        Label("Set as Writer", systemImage: "arrow.up.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, 6)
    }
}

// CBCharacteristic Extension
extension CBCharacteristic: @retroactive Identifiable {
    public var id: CBUUID { uuid }
}

// 预览 Preview
#Preview {
    ContentView()
}
