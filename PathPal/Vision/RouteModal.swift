//
//  RouteModal.swift
//  PathPal
//
//  Created by Suji Lee on 12/26/23.
//

import SwiftUI

struct RouteModal: View {
    
    @ObservedObject var mapVM: MapViewModel
    @Binding var cameraController: CameraViewController?
    
    var body: some View {
        VStack {
                VStack {
                    Text("경로 안내")
                        .font(.system(size: 17, weight: .semibold))
                    ScrollView {
                        HStack(spacing: 15) {
                            if let totalDistance = mapVM.routeProperties?.totalDistance, let totalTime = mapVM.routeProperties?.totalTime {
                                let time = "소요 시간 " + String(totalTime) + "초"
                                let distance = "총 거리 " + String(totalDistance) +
                                "m"
                                Image("PathPal")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 15)
                                Text(distance)
                                Text(time)
                                Spacer()
                            }
                        }
                        .font(.system(size: 16, weight: .medium))
                        .padding(15)
                        .background(Color.hexF4F8FF)
                        VStack(alignment: .leading) {
                            ForEach(mapVM.routeInstruction, id: \.self) { route in
                                VStack(alignment: .leading) {
                                    Text(route)
                                        .font(.system(size: 15))
                                }
                                .padding(10)
                                Divider()
                                
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 20)
                    }
                    .frame(width: screenWidth * 0.9, height: screenHeight * 0.7)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.hex959595.opacity(0.7), lineWidth: 0.7)
                    }
                }
                .padding(.vertical)
        }
        .onAppear {
            cameraController?.stopCamera()
        }
        .onDisappear {
            cameraController?.startCamera()
        }
    }

}
