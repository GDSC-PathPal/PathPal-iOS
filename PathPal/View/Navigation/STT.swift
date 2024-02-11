//
//  STT.swift
//  PathPal
//
//  Created by Suji Lee on 2/8/24.
//

import Foundation
import SwiftUI

struct MicRecordView: View {
    
 @StateObject var sttManager: GoogleSpeechManager = GoogleSpeechManager()
//    @Binding var isShowingMic: Bool
    @State var isRecording: Bool = false
    @StateObject var ttsManager: SpeechService = SpeechService()
    
    @State var transcripts: [String] = []
    @Binding var query: String
    @State var hasGuidedQuery: Bool = false
    
    @Binding var isShowingMic: Bool
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(.white.opacity(0.6))
                .ignoresSafeArea()
            VStack(spacing: 40) {
                Button(action: {
                    run()
                }, label: {
                    Image("RecordMic")
                })
                .accessibilityLabel("마이크 버튼")
                .accessibilityHint(Text("버튼을 눌러 마이크를 켜고 끌 수 있습니다"))
                
                //결과
                VStack {
                    if isRecording {
                        Text("음성 인식 중")
                    } else {
                        Text("검색어 : \(query)")
                    }
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.hex292929)
                
                //완료하기 버튼
                Button(action: {
                    isShowingMic = false
                }, label: {
                    RoundedRectangle(cornerRadius: 20)
                        .frame(width: screenWidth * 0.6, height: 45)
                        .foregroundStyle(Color.hex246FFF)
                        .overlay {
                            Text("완료하기")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.white)
                        }
                })
                .disabled(isRecording || hasGuidedQuery == false)
            }
            .foregroundStyle(Color.white)
            .frame(width: screenWidth * 0.87, height: screenHeight * 0.6)
        }
        .onChange(of: sttManager.isFinal) { isFinal in
            if isFinal {
                transcripts.append(sttManager.getPrevTranscript())
                query = transcripts.first ?? ""
                var ttsString: String = "\(query)를 검색어로 설정합니다"
                ttsManager.speak(text: ttsString)
                hasGuidedQuery = true
            }
        }
    }
    
    func run() {
        isRecording = !isRecording
        
        if isRecording {
            transcripts.removeAll()
            sttManager.startRecording()
            print("Recording ...")
        } else {
            print("Recording stopped.")
            sttManager.stopRecording()
        }
    }
}


struct GoogleSTTView: View {
    @State var isRecording = false
    @StateObject var speechManager = GoogleSpeechManager()
    @State var transcripts: [String] = []
    
    var body: some View {
        VStack {
            Button(action: run, label: { Text("Run") })
            
            ForEach($transcripts, id: \.self) { $tr in
                TextEditor(text: $tr)
            }
            
            TextEditor(text: $speechManager.transcript)
        }
        .padding()
        .onChange(of: speechManager.isFinal) { isFinal in
            if isFinal {
                transcripts.append(speechManager.getPrevTranscript())
            }
        }
    }
    
    func run() {
        isRecording = !isRecording
        
        if isRecording {
            speechManager.startRecording()
            print("Recording ...")
        } else {
            speechManager.stopRecording()
            print("Recording stopped.")
        }
    }
}
