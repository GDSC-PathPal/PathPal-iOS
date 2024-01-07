//
//  NavigationPage.swift
//  PathPal
//
//  Created by Suji Lee on 12/26/23.
//

import SwiftUI

struct NavigationPage: View {
    
    var body: some View {
        NavigationStack {
            // 출발지
            VStack(alignment: .leading) {
                Text("출발지")
                    .font(.system(size: 18, weight: .semibold))
                RoundedRectangle(cornerRadius: 25.5)
                    .stroke(Color.hexBBD2FF)
                    .frame(width: screenWidth * 0.85, height: 43)
                    .overlay {
                        HStack {
                            Text("현재 위치를 출발지로 설정 중")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.hex959595)
                            Spacer()
                        }
                        .padding()
                    }
            }
            .padding(.bottom)
            
            // 도착지
            VStack(alignment: .leading) {
                Text("도착지")
                    .font(.system(size: 18, weight: .semibold))
                NavigationLink(destination: {
                    SearchView()
                }, label: {
                    RoundedRectangle(cornerRadius: 25.5)
                        .stroke(Color.hexBBD2FF)
                        .frame(width: screenWidth * 0.85, height: 43)
                        .overlay {
                            HStack {
                                Text("도착지 검색")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.hex959595)
                                Spacer()
                            }
                            .padding()
                        }
                })
            }
            Divider()
                .padding()
            
            // 전체 경로 안내(도착지 입력 시 활성화)
            VStack {
                Text("경로 안내")
                    .foregroundStyle(Color.hex292929)
                    .font(.system(size: 18, weight: .semibold))
                
                
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.hexCECECE, lineWidth: 1)
                    .frame(width: 327, height: screenHeight * 0.4)
                    .overlay {
                        Image("LogoOpacity")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 150)
                        ScrollView {
                        }
                        .padding()
                    }
            }
            
            // 출발하기
            VStack {
                Button(action: {
                    
                }, label: {
                    RoundedRectangle(cornerRadius: 25.5)
                        .frame(width: screenWidth * 0.85, height: 50)
                        .foregroundStyle(Color.hex246FFF)
                        .overlay {
                            Text("출발하기")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.white)
                        }
                })
            }
            .padding()
        }
    }
}

#Preview {
    NavigationPage()
}
