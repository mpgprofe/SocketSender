//
//  ContentView.swift
//  SocketSender
//
//  Created by Jorge Mendoza on 12/19/24.
// Modified by Mpg 12/31/24
//

import Network
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var ipAddress: String = "192.168.100.154"  // Dirección IP por defecto
    @State private var port: String = "8080"  // Puerto por defecto
    @State private var selectedImage: UIImage? = nil  // Imagen seleccionada
    @State private var isImagePickerPresented = false  // Flag para presentar el selector de imagen
    @State private var eventCode: String = ""  // Campo para el Código del EVENTO
    @FocusState private var isIPActive: Bool  // Usar FocusState para manejar el enfoque en IP
    @FocusState private var isPortActive: Bool  // Usar FocusState para manejar el enfoque en el puerto
    @FocusState private var isEventCodeActive: Bool  // Usar FocusState para manejar el enfoque en el código de evento
    let client = Client()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {

                // Campo de IP
                TextField("Server IP Address", text: $ipAddress)
                    .keyboardType(.numbersAndPunctuation)
                    .focused($isIPActive)  // Usamos el FocusState aquí
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, 10)

                // Campo de Puerto
                TextField("Port", text: $port)
                    .keyboardType(.numberPad)
                    .focused($isPortActive)  // Usamos el FocusState aquí
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.bottom, 10)

                // Campo de Código del EVENTO (convertir a mayúsculas automáticamente)
                TextField("Código del EVENTO", text: $eventCode)
                    .focused($isEventCodeActive)  // Usamos el FocusState aquí
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.allCharacters)  // Convierte a mayúsculas automáticamente
                    .padding(.bottom, 10)

                Divider()

                // Mostrar la imagen seleccionada
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding(.bottom, 10)
                } else {
                    Text("No image selected")
                        .padding(.bottom, 10)
                }

                // Botón para seleccionar la imagen
                Button(action: {
                    isImagePickerPresented.toggle()
                }) {
                    Text("Select Image")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Divider()

                // Botón para enviar la imagen al servidor
                Button(action: {
                    guard let image = selectedImage, !eventCode.isEmpty else { return }
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        let host = ipAddress
                        let portNumber = UInt16(port) ?? 8080
                        client.connectToServer(host: host, port: portNumber)
                        client.sendImage(
                            imageData, fileName: "\(eventCode).jpg", quantity: 1)
                    }
                }) {
                    Text("Send Image")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

            }
            .padding()
            .navigationTitle("Image Sender")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isIPActive || isPortActive || isEventCodeActive {
                        Button(action: {
                            isIPActive = false
                            isPortActive = false
                            isEventCodeActive = false
                        }) {
                            Label(
                                "Dismiss",
                                systemImage:
                                    "keyboard.chevron.compact.down.fill"
                            )
                            .labelStyle(.iconOnly)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isImagePickerPresented) {
            ImagePicker(selectedImage: $selectedImage)
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?

    class Coordinator: NSObject, UIImagePickerControllerDelegate,
        UINavigationControllerDelegate
    {
        var parent: ImagePicker

        init(parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController
                .InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController, context: Context
    ) {
        // Actualización de la vista si es necesario (no se requiere en este caso)
    }
}

class Client {
    private var connection: NWConnection?

    func connectToServer(host: String, port: UInt16) {
        connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: port), using: .tcp)
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

    func sendImage(_ imageData: Data, fileName: String, quantity: Int) {
        guard let connection = connection else { return }

        // 1. Enviar el nombre del archivo (UTF-8)
        guard let fileNameData = fileName.data(using: .utf8) else { return }

        // La longitud de la cadena en UTF-8 (2 bytes)
        let length = UInt16(fileNameData.count)
        var lengthData = Data()
        withUnsafeBytes(of: length.bigEndian) {
            lengthData.append(contentsOf: $0)
        }

        // Enviar primero la longitud (2 bytes) y luego los datos de la cadena
        let fullData = lengthData + fileNameData

        //Enviamos el nombre del archivo:
        connection.send(
            content: fullData,
            completion: .contentProcessed { error in
                if let error = error {
                    print(
                        "Failed to send initial data (name + quantity): \(error)"
                    )
                } else {
                    print("Initial data sent successfully!")
                }
            })

        // 2. Enviar la cantidad de archivos
        var quantityData = UInt32(quantity).bigEndian
        let quantityDataConverted = Data(
            bytes: &quantityData, count: MemoryLayout<UInt32>.size)

        // 3. Enviar la cantidad de impresiones
        let initialData = quantityDataConverted

        connection.send(
            content: initialData,
            completion: .contentProcessed { error in
                if let error = error {
                    print(
                        "Failed to send initial data (name + quantity): \(error)"
                    )
                } else {
                    print("Initial data sent successfully!")
                }
            })

        // 4. Enviar los datos del archivo en bloques de 8192 bytes
        let chunkSize = 8192
        var offset = 0
        let totalSize = imageData.count

        while offset < totalSize {
            let chunk = imageData.subdata(
                in: offset..<min(offset + chunkSize, totalSize))

            connection.send(
                content: chunk,
                completion: .contentProcessed { error in
                    if let error = error {
                        print("Failed to send image chunk: \(error)")
                    } else {
                        print("Image chunk sent successfully!")
                    }
                })

            offset += chunkSize
        }
    }
}

#Preview {
    ContentView()
}
