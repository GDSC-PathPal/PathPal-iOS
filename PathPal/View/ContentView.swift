//
//  ContentView.swift
//  PathPal
//
//  Created by Suji Lee on 12/26/23.
//

import SwiftUI

let screenWidth = UIScreen.main.bounds.width
let screenHeight = UIScreen.main.bounds.height

struct ContentView: View {
    @StateObject var mapVM: MapViewModel = MapViewModel()
    @State private var showLaunchScreen = true
    
    var body: some View {
        ZStack {
            if showLaunchScreen {
                LaunchScreen()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            withAnimation {
                                showLaunchScreen = false // 런치 스크린을 숨기고
                            }
                        }
                    }
            } else {
//                NavigationPage(mapVM: mapVM)
                VisionView(mapVM: mapVM)
            }
        }
    }
}

struct LaunchScreen: View {
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(Color.white)
            Image("LogoWithText")
        }
        .ignoresSafeArea()
    }
}
#Preview {
    ContentView()
}
