//
//  Camera.swift
//  PathPal
//
//  Created by Suji Lee on 12/26/23.
//

import SwiftUI
import AVFoundation
import Starscream
import Combine

struct ResponseModel: Codable {
    var koreanTTSString: String
    var englishTTSString: String
    var needAlert: Bool
}

struct responseTextModel: Codable {
var text: String
}

let domain = Bundle.main.object(forInfoDictionaryKey: "DOMAIN") as? String ?? ""


class CameraViewController: UIViewController, WebSocketDelegate, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    private var lastFrameTime = Date()
    private var speechService: SpeechService = SpeechService()

    let websocketURL = URL(string: "ws://\(domain)/socket")!
    @Published var visionResponses: [ResponseModel] = []
    

    var previewLayer: AVCaptureVideoPreviewLayer!
    var websocket: WebSocket!

    var cancellables = Set<AnyCancellable>()
    let receivedDataSubject = PassthroughSubject<String, Never>()

    var captureSession: AVCaptureSession?
    
    var isModalPresented: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        setupWebSocket()
        setupDataProcessing()
    }
    
    func startCamera() {
        if captureSession?.isRunning == false {
            captureSession?.startRunning()
        }
    }

    func stopCamera() {
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }
    
    func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .medium

        guard let backCamera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: backCamera) else { return }

        captureSession?.addInput(input)

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String): NSNumber(value: kCVPixelFormatType_32BGRA)]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if ((captureSession?.canAddOutput(videoOutput)) != nil) {
            captureSession?.addOutput(videoOutput)
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession ?? captureSession!)
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func setupWebSocket() {
        var request = URLRequest(url: websocketURL)
        websocket = WebSocket(request: request)
        websocket.delegate = self
        websocket.connect()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard !isModalPresented else { return }
        
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastFrameTime) >= 1.0 {
            lastFrameTime = currentTime
            guard let image = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }

            let resizedImage = resizeImage(image, targetSize: CGSize(width: 640, height: 640))

            if let jpegData = resizedImage.jpegData(compressionQuality: 0.5) {
                websocket.write(data: jpegData)
                print("Image captured and sent: \(Date())") // 로그 출력
            } else {
                print("Failed to convert image to JPEG")
            }
        }
    }

    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let newSize: CGSize

        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { (context) in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    func setupDataProcessing() {
        receivedDataSubject
            .flatMap(maxPublishers: .max(10)) { jsonString in
                // 비동기적으로 데이터를 처리하고 결과를 Just로 감싸 반환
                Future<String, Never> { promise in
                    DispatchQueue.global(qos: .background).async {
                        self.handleWebSocketResponse(jsonString)
                        promise(.success(jsonString)) // 처리 후 성공 결과 전달
                    }
                }
            }
            .receive(on: DispatchQueue.global(qos: .background))
            .sink(receiveValue: { data in
                // 결과 처리가 필요한 경우 여기에서 수행
            })
            .store(in: &cancellables)
    }

    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .text(let string):
//            print("Received text: \(string)")
            receivedDataSubject.send(string) // 받은 데이터를 Combine 스트림으로 전달
        case .disconnected(let reason, let code):
            print("WebSocket disconnected: \(reason) with code: \(code)")
        case .error(let error):
            if let error = error {
                print("WebSocket encountered an error: \(error)")
            }
        default:
            break
        }
    }

    func handleWebSocketResponse(_ jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else {
            print("Error: Unable to convert received text to data")
            return
        }

        do {
            let responseData = try JSONDecoder().decode([ResponseModel].self, from: data)
            self.visionResponses = responseData
            print("비전 응답 : ", responseData)
            for response in responseData {
                print("Korean: \(response.koreanTTSString)")
                //테스트
                speechService.speak(text: response.koreanTTSString)

                print("English: \(response.englishTTSString)")
                print("Alert Needed: \(response.needAlert)")
            }
        } catch {
            print("Error parsing JSON: \(error)")
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    @Binding var cameraController: CameraViewController?

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        self.cameraController = controller
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}

    typealias UIViewControllerType = CameraViewController
}


struct VisionView: View {
    @ObservedObject var mapVM: MapViewModel

    @State private var showModal = false
    @State var cameraController: CameraViewController?

    var body: some View {
        VStack(spacing: 50) {
            CameraView(cameraController: $cameraController)
                .padding(.top, -100)
            Button(action: {
                self.showModal = true
                self.cameraController?.isModalPresented = true
            }, label: {
                RoundedRectangle(cornerRadius: 8)
                    .frame(width: screenWidth * 0.85, height: 50)
                    .foregroundStyle(Color.hex246FFF)
                    .overlay {
                        Text("경로 다시보기")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
            })
            .sheet(isPresented: $showModal, onDismiss: {
                self.cameraController?.isModalPresented = false
            }) {
                RouteModal(mapVM: mapVM, cameraController: $cameraController)
            }
        }
        .onDisappear {
            cameraController?.stopCamera()
        }
    }
}

#Preview {
    VisionView(mapVM: MapViewModel())
}


//struct PreviewView: UIViewRepresentable {
//    var session: AVCaptureSession
//
//    func makeUIView(context: Context) -> UIView {
//        let view = UIView()
//
//        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
//        previewLayer.videoGravity = .resizeAspectFill
//        view.layer.addSublayer(previewLayer)
//
//        DispatchQueue.main.async {
//            previewLayer.frame = view.bounds
//        }
//
//        return view
//    }
//
//    func updateUIView(_ uiView: UIView, context: Context) {}
//}






//class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate, WebSocketDelegate, ObservableObject {
//    
//    private var speechService: SpeechService = SpeechService()
//        
//    let websocketURL = URL(string: "ws://\(domain)/socket")!
//    
//    @Published var visionResponses: [ResponseModel] = []
//    
//    var captureSession: AVCaptureSession!
//    var previewLayer: AVCaptureVideoPreviewLayer!
//    var websocket: WebSocket!
//    
//    var cancellables = Set<AnyCancellable>()
//    let receivedDataSubject = PassthroughSubject<String, Never>()
//    
//    var captureTimer: Timer?
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        setupCaptureSession()
//        setupWebSocket()
//        setupDataProcessing() // 데이터 처리 설정 추가
//
//        // 타이머 설정: 1초마다 이미지 캡처 및 전송
//        captureTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(captureAndSendImage), userInfo: nil, repeats: true)
//    }
//    
//    func setupCaptureSession() {
//        captureSession = AVCaptureSession()
//        captureSession.sessionPreset = .medium
//        
//        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video),
//              let input = try? AVCaptureDeviceInput(device: backCamera) else { return }
//        
//        captureSession.addInput(input)
//        
//        let photoOutput = AVCapturePhotoOutput()
//        photoOutput.isHighResolutionCaptureEnabled = true // 고해상도 캡처 활성화
//        if captureSession.canAddOutput(photoOutput) {
//            captureSession.addOutput(photoOutput)
//        }
//        
//        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
//        previewLayer.frame = view.frame
//        view.layer.addSublayer(previewLayer)
//        
//        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
//            self?.captureSession.startRunning()
//        }
//    }
//    
//    func setupWebSocket() {
//        var request = URLRequest(url: websocketURL)
//        websocket = WebSocket(request: request)
//        websocket.delegate = self
//        websocket.connect()
//    }
//    
//    @objc func captureAndSendImage() {
//        let photoSettings = AVCapturePhotoSettings()
//        photoSettings.isHighResolutionPhotoEnabled = true
//        
//        capturePhoto(with: photoSettings)
//    }
//    
//    func capturePhoto(with settings: AVCapturePhotoSettings) {
//        guard let photoOutput = captureSession.outputs.first as? AVCapturePhotoOutput else { return }
//        
//        photoOutput.capturePhoto(with: settings, delegate: self)
//    }
//    
//    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
//        var imageData: Data?
//        
//        if let data = photo.fileDataRepresentation(),
//           let image = UIImage(data: data) {
//            let resizedImage = resizeImage(image, targetSize: CGSize(width: 640, height: 640))
//            
//            if let jpegData = resizedImage.jpegData(compressionQuality: 0.3) {
//                imageData = jpegData
//            }
//        }
//        
//        if let imageData = imageData {
//            websocket.write(data: imageData)
//        }
//    }
//
//    func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
//        let size = image.size
//        let widthRatio = targetSize.width / size.width
//        let heightRatio = targetSize.height / size.height
//        let newSize: CGSize
//        
//        if widthRatio > heightRatio {
//            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
//        } else {
//            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
//        }
//        
//        let renderer = UIGraphicsImageRenderer(size: newSize)
//        return renderer.image { (context) in
//            image.draw(in: CGRect(origin: .zero, size: newSize))
//        }
//    }
//    
//    func setupDataProcessing() {
//        receivedDataSubject
//            .flatMap(maxPublishers: .max(10)) { jsonString in
//                // 비동기적으로 데이터를 처리하고 결과를 Just로 감싸 반환
//                Future<String, Never> { promise in
//                    DispatchQueue.global(qos: .background).async {
//                        self.handleWebSocketResponse(jsonString)
//                        promise(.success(jsonString)) // 처리 후 성공 결과 전달
//                    }
//                }
//            }
//            .receive(on: DispatchQueue.global(qos: .background))
//            .sink(receiveValue: { data in
//                // 결과 처리가 필요한 경우 여기에서 수행
//            })
//            .store(in: &cancellables)
//    }
//
//    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
//        switch event {
//        case .text(let string):
////            print("Received text: \(string)")
//            receivedDataSubject.send(string) // 받은 데이터를 Combine 스트림으로 전달
//        case .disconnected(let reason, let code):
//            print("WebSocket disconnected: \(reason) with code: \(code)")
//        case .error(let error):
//            if let error = error {
//                print("WebSocket encountered an error: \(error)")
//            }
//        default:
//            break
//        }
//    }
//    
//    func handleWebSocketResponse(_ jsonString: String) {
//        guard let data = jsonString.data(using: .utf8) else {
//            print("Error: Unable to convert received text to data")
//            return
//        }
//         
//        do {
//            let responseData = try JSONDecoder().decode([ResponseModel].self, from: data)
//            self.visionResponses = responseData
//            print("비전 응답 : ", responseData)
//            for response in responseData {
//                print("Korean: \(response.koreanTTSString)")
//                //테스트
//                speechService.speak(text: response.koreanTTSString)
//                
//                print("English: \(response.englishTTSString)")
//                print("Alert Needed: \(response.needAlert)")
//            }
//        } catch {
//            print("Error parsing JSON: \(error)")
//        }
//    }
//
//     deinit {
//         captureTimer?.invalidate()
//     }
//}
//
//
//
//struct CameraView: UIViewControllerRepresentable {
//        
//    func makeUIViewController(context: Context) -> CameraViewController {
//        return CameraViewController()
//    }
//    
//    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
//    
//    typealias UIViewControllerType = CameraViewController
//}
//
