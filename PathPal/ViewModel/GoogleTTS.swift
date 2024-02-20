//
//  GoogleTTS.swift
//  PathPal
//
//  Created by Suji Lee on 1/17/24.
//

import Foundation
import Combine
import AVFoundation
import UIKit
import Combine


enum VoiceType: String {
    case undefined
    case waveNetMale = "en-US-Wavenet-D"
    case standardFemale = "en-US-Standard-E"
    case standardMale = "en-US-Standard-D"
    case koreanFemale = "ko-KR-Neural2-A" // Add Korean female voice type
}

struct TTSRequest: Codable {
    struct Input: Codable {
        let text: String
    }
    struct Voice: Codable {
        let languageCode: String
        let name: String
        let ssmlGender: String
    }
    struct AudioConfig: Codable {
        let audioEncoding: String
    }

    let input: Input
    let voice: Voice
    let audioConfig: AudioConfig
}

struct TTSResponse: Codable {
    let audioContent: String
}

let ttsToken = Bundle.main.object(forInfoDictionaryKey: "GCLOUD_AUTH_ACCESS_TOKEN") as? String ?? ""
let ttsApiKey = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_TTS_API_KEY") as? String ?? ""

let ttsAPIUrl = "https://texttospeech.googleapis.com/v1beta1/text:synthesize"
let APIKey = ttsApiKey

enum SpeechServiceError: Error, LocalizedError {
    case cannotCreateAudioSession
    case cannotPlayAudio

    var errorDescription: String? {
        switch self {
        case .cannotCreateAudioSession:
            return "Unable to create audio session."
        case .cannotPlayAudio:
            return "Cannot play audio."
        }
    }
}

class SpeechService: ObservableObject {
    @Published var isBusy = false

    private var cancellables = Set<AnyCancellable>()
    private var player: AVAudioPlayer?
    
    func speak(text: String, voiceType: VoiceType = .koreanFemale) {
        guard !isBusy else {
            return
        }

        isBusy = true
        let postData = buildPostData(text: text, voiceType: voiceType)
        let headers = ["X-Goog-Api-Key": APIKey, "Content-Type": "application/json; charset=utf-8"]

        makePOSTRequest(url: ttsAPIUrl, postData: postData, headers: headers)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error: \(error)")
                    self.isBusy = false
                }
            }, receiveValue: { [weak self] (response: TTSResponse) in
                self?.playAudio(from: response.audioContent)
            })
            .store(in: &cancellables)
    }

    private func playAudio(from base64String: String) {
        guard let audioData = Data(base64Encoded: base64String) else {
            self.isBusy = false
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            self.player = try AVAudioPlayer(data: audioData)
            self.player?.play()

            self.isBusy = false
        } catch {
            print("Audio playback error: \(error)")
            self.isBusy = false
        }
    }

    // Combine을 사용한 POST 요청 함수
    private func makePOSTRequest(url: String, postData: Data, headers: [String: String]) -> AnyPublisher<TTSResponse, Error> {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.httpBody = postData
        headers.forEach { request.addValue($0.value, forHTTPHeaderField: $0.key) }

        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: TTSResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    private func buildPostData(text: String, voiceType: VoiceType) -> Data {
        
        var voiceParams: [String: Any] = [
            // All available voices here: https://cloud.google.com/text-to-speech/docs/voices
            "languageCode": "ko-KR"
        ]
        
        if voiceType != .undefined {
            voiceParams["name"] = voiceType.rawValue
        }
        
        let params: [String: Any] = [
            "input": [
                "text": text
            ],
            "voice": voiceParams,
            "audioConfig": [
                // All available formats here: https://cloud.google.com/text-to-speech/docs/reference/rest/v1beta1/text/synthesize#audioencoding
                "audioEncoding": "LINEAR16"
            ]
        ]
        
        // Convert the Dictionary to Data
        let data = try! JSONSerialization.data(withJSONObject: params)
        return data
    }
    
    // Just a function that makes a POST request.
    private func makePOSTRequest(url: String, postData: Data, headers: [String: String] = [:]) -> [String: AnyObject] {
        var dict: [String: AnyObject] = [:]
        
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.httpBody = postData
        
        for header in headers {
            request.addValue(header.value, forHTTPHeaderField: header.key)
        }
        
        // Using semaphore to make request synchronous
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: AnyObject] {
                dict = json
            }
            
            semaphore.signal()
        }
        
        task.resume()
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        return dict
    }
}
