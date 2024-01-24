//
//  NavigationPage.swift
//  PathPal
//
//  Created by Suji Lee on 12/26/23.
//

import SwiftUI
import Combine

struct NavigationPage: View {
    
    @ObservedObject var mapVM: MapViewModel
    @State private var errorMsg: String?
    var cancellables = Set<AnyCancellable>()
    @State var isFetched: Bool = false
    
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
                            Text(mapVM.startingPoint == nil ? "현재 위치를 출발지로 설정 중" : "현재 위치를 출발지로 설정 완료")
                                .font(.system(size: 14, weight: mapVM.isLoading ? .regular : .medium))
                                .foregroundColor(mapVM.isLoading ? .hex959595 : .hex292929)
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
                    SearchView(mapVM: mapVM)
                }, label: {
                    RoundedRectangle(cornerRadius: 25.5)
                        .stroke(Color.hexBBD2FF)
                        .frame(width: screenWidth * 0.85, height: 43)
                        .overlay {
                            HStack {
                                if mapVM.destination.name == "" {
                                    Text("도착지 검색")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.hex959595)
                                } else {
                                    HStack {
                                        Text(mapVM.destination.name)
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.hex292929)
                                        Spacer()
                                        Button(action: {
                                            mapVM.destination.name = ""
                                            isFetched = false
                                        }, label: {
                                            Image(systemName: "x.circle")
                                        })
                                    }
                                }
                                Spacer()
                            }
                            .padding()
                        }
                })
            }
            Divider()
                .padding()
            if !mapVM.isFetching && !isFetched {
            VStack {
                    Button("길 찾기") {
                        fetchRoute()
                    }
                    .padding()
                    .disabled(mapVM.isFetching)
                }
            } else {
                VStack {
                    if mapVM.isFetching {
                        Text("경로 찾는 중")
                    } else {
                        //경로 안내
                        VStack {
                            if let totalDistance = mapVM.routeProperties?.totalDistance, let totalTime = mapVM.routeProperties?.totalTime {
                                let time = "소요 시간 : " + String(totalTime) + "초"
                                let distance = "총 거리 : " + String(totalDistance) +
                                "m"
                                Text(distance)
                                Text(time)
                            }
                            ForEach(mapVM.routeInstruction, id: \.self) { route in
                                Text(route)
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
        }
    }
    
    func fetchRoute() {
        isFetched = false
        let startName = "내 위치".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        let endName = mapVM.destination.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        
        let parameters = [
            "startX": mapVM.startingPoint.noorLon ?? "",
            "startY": mapVM.startingPoint.noorLat ?? "",
            "angle": 20,
            "speed": 1,
            "endPoiId": mapVM.destination.id,
            "endX": mapVM.destination.noorLon ?? "",
            "endY": mapVM.destination.noorLat ?? "",
            "reqCoordType": "WGS84GEO",
            "startName": startName ?? "",
            "endName": endName ?? "",
            "searchOption": "4",
            "resCoordType": "WGS84GEO",
            "sort": "index"
        ] as [String : Any]
        
        mapVM.isFetching = true
        mapVM.fetchRoute(parameters: parameters)
            .sink(receiveCompletion: { _ in
                mapVM.isFetching = false
            }, receiveValue: { data in
                print("경로 데이터 : ", data)
                mapVM.routeProperties = data.features[0].properties
                print("캐싱한 porperty 데이터", mapVM.routeProperties)
                mapVM.generateNavigationInstructions(response: data)
                isFetched = true
            })
            .store(in: &mapVM.cancellables)
    }
}

#Preview {
    NavigationPage(mapVM: MapViewModel())
}
