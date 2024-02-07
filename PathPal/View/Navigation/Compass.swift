//
//  Compass.swift
//  PathPal
//
//  Created by Suji Lee on 12/26/23.
//

import SwiftUI

struct Compass: View {
    
    @ObservedObject var mapVM: MapViewModel
    @State var navigateToVisionPage: Bool = false
    
    var body: some View {
            VStack(spacing: 30) {
                VStack {
                    Text("출발 방향 맞추기")
                        .foregroundStyle(Color.hex292929)
                        .font(.system(size: 19, weight: .semibold))
                    Text("방향 설정이 완료되면 시각 보조 화면으로 이동합니다")
                        .font(.system(size: 15))
                        .padding(.bottom)
                    // 안내 메세지
                    Text("진동이 울릴 때까지 출발 방향을 변경해주세요")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.hex353535)
                        .frame(width: 200, alignment: .center)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, -30)
                // 나침반
                ZStack {

                    Image("CompassLine")
                        .resizable()
                        .scaledToFit()
                        .frame(width: screenWidth * 0.8)
                        .rotationEffect(.degrees(mapVM.userHeading))
                        .onChange(of: mapVM.isHeadingRightDirection) { isRightDirection in
                            if isRightDirection {
                                triggerHapticFeedback()
                                // 0.1초의 지연 후 navigateToVisionPage를 true로 설정
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    navigateToVisionPage = true
                                }
                            }
                        }
                    Image("CompassCenter")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100)
                    // 목표 방향을 가리키는 화살표
                    Image(systemName: "arrow.up")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                        .rotationEffect(.degrees(mapVM.startHeading ?? 0))
                }
                .accessibilityHidden(true)
                NavigationLink(destination: VisionView(mapVM: mapVM), isActive: $navigateToVisionPage) {
                    EmptyView()
                }
            }
            .background(Color.white)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing, content: {
                    NavigationLink(destination: {
                        MapView(mapVM: mapVM)
                    }, label: {
                        Text("지도 보기")
                    })
                })
            }
    }
    
    private func triggerHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
}

// 세모 모양을 그리는 구조체
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        
        return path
    }
}
