//
//  VisionPage.swift
//  PathPal
//
//  Created by Suji Lee on 12/26/23.
//

import SwiftUI
import UIKit
import Combine
import AVFoundation


struct VisionPage: View {
    
    @StateObject private var speechService = SpeechService()
    var voiceType: VoiceType = .koreanFemale

    var body: some View {
        Button("음성 듣기") {
            speechService.speak(text: "우측에 볼라드 감지", voiceType: voiceType)
        }
        .disabled(speechService.isBusy)
    }
}

#Preview {
    VisionPage()
}

