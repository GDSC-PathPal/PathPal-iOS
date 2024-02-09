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


struct responseTextModel: Codable {
    var text: String
}

//let domain = Bundle.main.object(forInfoDictionaryKey: "DOMAIN") as? String ?? ""

class CameraViewController: UIViewController, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private var lastFrameTime = Date()
//    private var speechService: SpeechService = SpeechService()
    
    var totalTime: String = ""
    
    //    let websocketURL = URL(string: "ws://\(domain)/socket")!
//    @Published var visionResponses: [ResponseModel] = []
    
    var previewLayer: AVCaptureVideoPreviewLayer!
//    var websocket: WebSocket!
    
    var cancellables = Set<AnyCancellable>()
//    let receivedDataSubject = PassthroughSubject<String, Never>()
    
    var captureSession: AVCaptureSession?
    
    var isCameraActive: Bool = false {
        didSet {
            if isCameraActive {
                startCamera()
            } else {
                stopCamera()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        //        setupWebSocket(totalTime: totalTime)
//        setupDataProcessing()
    }
    
    func startCamera() {
        print("START CAMERA")
        if captureSession?.isRunning == false {
            captureSession?.startRunning()
        }
    }
    
    func stopCamera() {
        print("STOP CAMERA")
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCamera()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCamera()
    }
    
    func setupCaptureSession() {
        captureSession = AVCaptureSession()
        
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
        
        //
        previewLayer.videoGravity = .resizeAspectFill // 비율 유지하면서 채우기
        
        // 프레임을 뷰의 중앙에 1:1 비율로 설정
        let sideLength = min(view.bounds.width, view.bounds.height) // 가로와 세로 중 작은 값을 기준으로 함
        previewLayer.frame = CGRect(x: (view.bounds.width - sideLength) / 2, y: (view.bounds.height - sideLength) / 2, width: sideLength, height: sideLength)
        
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    private func cropToSquare(image: UIImage) -> UIImage? {
        let originalWidth = image.size.width
        let originalHeight = image.size.height
        let cropSize = min(originalWidth, originalHeight)
        
        let cropX = (originalWidth - cropSize) / 2
        let cropY = (originalHeight - cropSize) / 2
        
        let cropRect = CGRect(x: cropX, y: cropY, width: cropSize, height: cropSize)
        if let imageCropped = image.cgImage?.cropping(to: cropRect) {
            return UIImage(cgImage: imageCropped, scale: image.scale, orientation: image.imageOrientation)
        }
        
        return nil
    }
    
    //    func setupWebSocket(totalTime: String) {
    //        var request = URLRequest(url: websocketURL)
    //        request.setValue("600", forHTTPHeaderField: "time")
    //        websocket = WebSocket(request: request)
    //        websocket.delegate = self
    //        websocket.connect()
    //    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let currentTime = Date()
        if currentTime.timeIntervalSince(lastFrameTime) >= 4.0 {
            lastFrameTime = currentTime
            guard let image = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else { return }
            
            // 이미지를 중앙에서 1:1 비율로 자르기
            guard let croppedImage = cropToSquare(image: image) else { return }
            
            // 자른 이미지를 640x640 크기로 조정
            let processedImage = scaleToFillImage(croppedImage, targetSize: CGSize(width: 640, height: 640))
            
            if let jpegData = processedImage.jpegData(compressionQuality: 0.7) {
                SocketManager.shared.websocket.write(data: jpegData)
                print("Image captured and sent: \(Date())")
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
        let image = UIImage(cgImage: cgImage)
        
        // 이미지를 오른쪽으로 90도 회전
        return image.rotated(byDegrees: 90)
    }
    
    private func scaleToFillImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
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
    
//    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
//        switch event {
//        case .text(let string):
//            //            print("Received text: \(string)")
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
//                print("Alert Needed: \(response.needAlert)")
//                //테스트
//                speechService.speak(text: response.koreanTTSString)
//                if response.needAlert == "true" {
//                    AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
//                }
//                
//            }
//        } catch {
//            print("Error parsing JSON: \(error)")
//        }
//    }
}

struct CameraView: UIViewControllerRepresentable {
    @Binding var cameraController: CameraViewController?
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        self.cameraController = controller
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // 필요한 경우 여기서 카메라 상태를 업데이트할 수 있습니다.
        // 예를 들어, 외부 조건에 따라 startCamera 또는 stopCamera를 호출할 수 있습니다.
    }
    
    typealias UIViewControllerType = CameraViewController
}

struct VisionView: View {
    @ObservedObject var mapVM: MapViewModel
    @State var cameraController: CameraViewController?
    
    var body: some View {
        VStack(spacing: 50) {
            CameraView(cameraController: $cameraController)
                .padding(.top, -100)
                .onAppear {
                    cameraController?.startCamera()
                }
                .onDisappear {
                    cameraController?.stopCamera()
                }
            
            NavigationLink(destination: {
                RouteModal(mapVM: mapVM)
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
        }
        .onAppear {
            cameraController?.totalTime = mapVM.routeProperties?.totalTime?.description ?? ""
        }
        .onDisappear {
            mapVM.hasTriggeredHapticFeedback = false
            cameraController?.stopCamera()
        }
    }
}

extension UIImage {
    func rotated(byDegrees degrees: CGFloat) -> UIImage? {
        // 회전 각도를 라디안으로 변환
        let radians = degrees * CGFloat.pi / 180
        
        // 그래픽스 컨텍스트 설정
        var newSize = CGRect(origin: .zero, size: self.size).applying(CGAffineTransform(rotationAngle: radians)).size
        // 확장된 이미지 사이즈에서 공백을 제거하기 위해 절대값 적용
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // 변환을 위한 원점 조정
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: radians)
        
        // 이미지 그리기
        self.draw(in: CGRect(x: -self.size.width / 2, y: -self.size.height / 2, width: self.size.width, height: self.size.height))
        
        // 생성된 이미지 가져오기
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return rotatedImage
    }
}
