//
//  Camera.swift
//  PathPal
//
//  Created by Suji Lee on 12/26/23.
//

import SwiftUI

import SwiftUI
import AVFoundation
import Starscream

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, WebSocketDelegate {
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
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var videoOutput: AVCaptureVideoDataOutput!
    var websocket: WebSocket!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
        setupWebSocket()
    }
    
    func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .medium // 해상도 설정
        
        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video),
              let input = try? AVCaptureDeviceInput(device: backCamera) else { return }
        
        captureSession.addInput(input)
        
        // 비디오 출력 설정
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(videoOutput)
        
        // 카메라 미리보기
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.frame
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func setupWebSocket() {
        if let baseURL = Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String {
            var request = URLRequest(url: URL(string: baseURL)!) // 웹소켓 서버 URL
            websocket = WebSocket(request: request)
            websocket.delegate = self
            websocket.connect()
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let image = UIImage(cgImage: cgImage)
            
            if let jpegData = image.jpegData(compressionQuality: 0.5) {
                // 이미지를 JPEG으로 인코딩하고 WebSocket을 통해 서버로 전송
                websocket.write(data: jpegData)
            }
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
}

struct CameraView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraViewController {
        return CameraViewController()
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
    
    typealias UIViewControllerType = CameraViewController
}
#Preview {
    CameraView()
}
