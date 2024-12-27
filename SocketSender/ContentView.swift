//
//  ContentView.swift
//  SocketSender
//
//  Created by Jorge Mendoza on 12/19/24.
//

import SwiftUI
import Network

struct ContentView: View {
    @State var ipAddress:String = ""
    @State var text:String = ""
    @FocusState var isIPActive
    @FocusState var isTextActive
    let client = Client()
    var body: some View {
        NavigationStack{
            VStack(alignment: .leading) {
                
                TextField("Server IP Address", text: $ipAddress)
                    .keyboardType(.numbersAndPunctuation)
                    .focused($isIPActive)
                
                Divider()
                
                TextField("Text", text: $text)
                    .focused($isTextActive)
                
                Divider()
                    
                Button{
                    client.connectToServer(host: ipAddress, port: 8080)
                    client.sendText(text)
                } label: {
                    Text("Send Text")
                }.buttonStyle(.borderedProminent)
                
            }
            .padding()
            .toolbar{
                ToolbarItem(placement: .topBarTrailing) {
                    if isIPActive ||  isTextActive{
                        Button{
                            isIPActive = false
                            isTextActive = false
                        } label: {
                            Label("Dismiss", systemImage: "keyboard.chevron.compact.down.fill").labelStyle(.iconOnly)
                        }
                    }
                }
            }
            .navigationTitle("Socket")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

class Client {
    private var connection: NWConnection?

    func connectToServer(host: String, port: UInt16) {
        connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: port), using: .tcp)
        connection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Connected to server")
            case .failed(let error):
                print("Connection failed: \(error)")
            default:
                break
            }
        }
        connection?.start(queue: .main)
    }


    func sendText(_ text: String) {
        guard let connection = connection, let socketData = text.data(using: .utf8) else { return }
        
        var dataSize = UInt32(socketData.count).bigEndian // Convert to network byte order
        let sizeData = Data(bytes: &dataSize, count: MemoryLayout<UInt32>.size)
        
        // Combine the size and text data
        let fullData = sizeData + socketData //This might be the Windows socket data issue!

        connection.send(content: fullData, completion: .contentProcessed { error in
            if let error = error {
                print("Failed to send text: \(error)")
            } else {
                print("Text sent successfully!")
            }
        })
    }
}

#Preview {
    ContentView()
}
