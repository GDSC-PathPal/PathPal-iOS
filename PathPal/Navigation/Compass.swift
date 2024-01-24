//
//  Compass.swift
//  PathPal
//
//  Created by Suji Lee on 12/26/23.
//

import SwiftUI

struct Compass: View {
    var body: some View {
        VStack(spacing: 30) {
            Text("출발 방향 맞추기")
                .foregroundStyle(Color.hex292929)
                .font(.system(size: 19, weight: .semibold))
            // 안내 메세지
            Text("진동이 울릴 때까지 출발 방향을 변경해주세요")
                .foregroundStyle(Color.hex353535)
                .frame(width: 200, alignment: .center)
                .multilineTextAlignment(.center)
            // 나침반
            
            // 알림
            HStack {
                Text("설정 중")
                    .foregroundStyle(Color.hex454545)
            }
        }
    }
}

#Preview {
    Compass()
}
