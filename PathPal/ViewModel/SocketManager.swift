//
//  SocketManager.swift
//  PathPal
//
//  Created by Suji Lee on 2/7/24.
//

import Foundation
import AVFoundation
import Starscream
import Combine

let domain = Bundle.main.object(forInfoDictionaryKey: "DOMAIN") as? String ?? ""

class SocketManager: ObservableObject, WebSocketDelegate {
    
    static let shared = SocketManager()
    
    @Published private var _isSsocketConneted: Bool = false
    @Published var visionResponses: [ResponseModel] = []
    private var speechService: SpeechService = SpeechService()

    let websocketURL = URL(string: "ws://\(domain)/socket")!
    
    var websocket: WebSocket!
    let receivedDataSubject = PassthroughSubject<String, Never>()
    
    var cancellables = Set<AnyCancellable>()

    init() {}
    
    var isSocketConneted: Bool {
        get {
            return self._isSsocketConneted
        }
        set {
            self._isSsocketConneted = newValue
        }
    }
    
    func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected(let headers):
            print("WebSocket is connected: \(headers)")
            self.isSocketConneted = true  // 소켓 연결 상태 업데이트
            print("socketConnected is now true")

        case .disconnected(let reason, let code):
            print("WebSocket disconnected: \(reason) with code: \(code)")
            self.isSocketConneted = false  // 소켓 연결 해제 상태 업데이트
            print("socketConnected is now false")

        case .text(let string):
            // 받은 데이터를 Combine 스트림으로 전달
            receivedDataSubject.send(string)
            print("Received text: \(string)")

        case .error(let error):
            if let error = error {
                print("WebSocket encountered an error: \(error)")
                self.isSocketConneted = false  // 에러 발생 시 소켓 연결 해제 상태로 가정
                print("socketConnected is now false due to error")
            }

        default:
            break
        }
    }

    
    func setupWebSocket(totalTime: String) {
        var request = URLRequest(url: websocketURL)
        request.setValue("600", forHTTPHeaderField: "time")
        websocket = WebSocket(request: request)
        websocket.delegate = self
        websocket.connect()
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
                print("Alert Needed: \(response.needAlert)")
                //테스트
                speechService.speak(text: response.koreanTTSString)
                if response.needAlert == "true" {
                    AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                }
                
            }
        } catch {
            print("Error parsing JSON: \(error)")
        }
    }
}
