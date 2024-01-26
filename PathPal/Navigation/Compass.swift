//
//  Compass.swift
//  PathPal
//
//  Created by Suji Lee on 12/26/23.
//

import SwiftUI

struct Compass: View {
    
    @ObservedObject var mapVM: MapViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Text("출발 방향 맞추기")
                .foregroundStyle(Color.hex292929)
                .font(.system(size: 19, weight: .semibold))
            Text("설명 추가")
            // 안내 메세지
            Text("진동이 울릴 때까지 출발 방향을 변경해주세요")
                .foregroundStyle(Color.hex353535)
                .frame(width: 200, alignment: .center)
                .multilineTextAlignment(.center)
            // 나침반

                // 나침반 배경
                Image("Compass")
                    .resizable()
                    .scaledToFit()
                    .frame(width: screenWidth * 0.8)
                    .rotationEffect(.degrees(mapVM.userHeading))
                    .overlay {
                        if mapVM.isHeadingRightDirection {
                            Text("출발 방향임!!!!!!!")
                        }
                    }
        }
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
