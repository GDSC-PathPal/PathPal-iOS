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

let domain = Bundle.main.object(forInfoDictionaryKey: "DOMAIN") as? String ?? ""

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate, WebSocketDelegate {
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
          switch event {
          case .connected(let headers):
              print("websocket is connected: \(headers)")
          case .disconnected(let reason, let code):
              print("websocket is disconnected: \(reason) with code: \(code)")
          case .text(let string):
              print("Received text: \(string)")
          case .error(let error):
              print("An error occurred: \(String(describing: error))")
          default:
              break
          }
      }
    
    let websocketURL = URL(string: "ws://\(domain)/socket")!
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var websocket: WebSocket!
    
    var captureTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        setupWebSocket()
        
        // 타이머 설정: 1초마다 이미지 캡처 및 전송
        captureTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(captureAndSendImage), userInfo: nil, repeats: true)
    }
    
    func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .medium
        
        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video),
              let input = try? AVCaptureDeviceInput(device: backCamera) else { return }
        
        captureSession.addInput(input)
        
        let photoOutput = AVCapturePhotoOutput()
        photoOutput.isHighResolutionCaptureEnabled = true // 고해상도 캡처 활성화
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.frame
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func setupWebSocket() {
        var request = URLRequest(url: websocketURL)
        print(request)
        websocket = WebSocket(request: request)
        websocket.delegate = self
        websocket.connect()
    }
    
    @objc func captureAndSendImage() {
        let photoSettings = AVCapturePhotoSettings()
        photoSettings.isHighResolutionPhotoEnabled = true
        
        capturePhoto(with: photoSettings)
    }
    
    func capturePhoto(with settings: AVCapturePhotoSettings) {
        guard let photoOutput = captureSession.outputs.first as? AVCapturePhotoOutput else { return }
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        var imageData: Data?
        
        if let data = photo.fileDataRepresentation(),
           let image = UIImage(data: data) {
            let resizedImage = resizeImage(image, targetSize: CGSize(width: 640, height: 640))
            
            if let jpegData = resizedImage.jpegData(compressionQuality: 0.3) {
                imageData = jpegData
            }
        }
        
        if let imageData = imageData {
            websocket.write(data: imageData)
        }
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
    
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .connected(let headers):
            print("WebSocket connected: \(headers)")
        case .disconnected(let reason, let code):
            print("WebSocket disconnected: \(reason) with code: \(code)")
        default:
            break
        }
    }
    
    deinit {
        captureTimer?.invalidate()
    }
}

struct CameraView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraViewController {
        return CameraViewController()
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
    
    typealias UIViewControllerType = CameraViewController
}
