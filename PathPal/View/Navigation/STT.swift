//
//  STT.swift
//  PathPal
//
//  Created by Suji Lee on 2/8/24.
//

import Foundation
import SwiftUI

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

