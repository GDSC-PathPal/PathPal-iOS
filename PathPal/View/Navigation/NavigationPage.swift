//
//  NavigationPage.swift
//  PathPal
//
//  Created by Suji Lee on 12/26/23.
//

import SwiftUI
import Combine

enum SearchMode {
    case startingPoint
    case destination
}

struct NavigationPage: View {
    
    @ObservedObject var mapVM: MapViewModel
    @State private var errorMsg: String?
    var cancellables = Set<AnyCancellable>()
    @State var isFetched: Bool = false
    @State var searchMode: SearchMode = .startingPoint
    @State var totalString: String = ""
    
    // NavigationLink의 활성화 상태를 추적하는 새로운 @State 변수들
    @State private var isStartingPointActive = false
    @State private var isDestinationActive = false
    
    var body: some View {
        NavigationStack {
            VStack {
                // 출발지
                VStack(alignment: .leading) {
                    Text("출발지")
                        .font(.system(size: 17, weight: .semibold))
                    HStack(spacing: 15) {
                        //출발지 검색 버튼
                        NavigationLink(destination: SearchView(mapVM: mapVM, searchMode: .constant(SearchMode.startingPoint))) {
                            RoundedRectangle(cornerRadius: 25.5)
                                .stroke(Color.hexBBD2FF)
                                .frame(width: screenWidth * 0.75, height: 50)
                                .overlay {
                                    HStack {
                                        if mapVM.startingPoint.name == "" {
                                            Text("출발지 검색")
                                                .font(.system(size: 15))
                                                .foregroundStyle(Color.hex959595)
                                        } else {
                                            HStack {
                                                Text(mapVM.startingPoint.name)
                                                    .font(.system(size: 15))
                                                    .foregroundStyle(Color.hex292929)
                                                Spacer()
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                }
                        }
//                        .simultaneousGesture(TapGesture().onEnded {
//                            // NavigationLink가 활성화되기 전에 searchMode 값을 설정
//                            searchMode = .startingPoint
//                        })
                        //출발지 검색어 초기화 버튼
                        Button(action: {
                            mapVM.startingPoint.name = ""
                            mapVM.routeInstruction = []
                            isFetched = false
                        }, label: {
                            Image(systemName: "x.circle")
                                .font(.system(size: 20))
                        })
                        .accessibilityLabel(Text("출발지 초기화 버튼"))
                    }
                }
                .padding(.bottom)
                
                // 도착지
                VStack(alignment: .leading) {
                    Text("도착지")
                        .font(.system(size: 17, weight: .semibold))
                    HStack(spacing: 15) {
                        //도착지 검색 버튼
                        NavigationLink(destination: SearchView(mapVM: mapVM, searchMode: .constant(SearchMode.destination))) {
                            RoundedRectangle(cornerRadius: 25.5)
                                .stroke(Color.hexBBD2FF)
                                .frame(width: screenWidth * 0.75, height: 50)
                                .overlay {
                                    HStack {
                                        if mapVM.destination.name == "" {
                                            Text("도착지 검색")
                                                .font(.system(size: 15))
                                                .foregroundStyle(Color.hex959595)
                                        } else {
                                            HStack {
                                                Text(mapVM.destination.name)
                                                    .font(.system(size: 15))
                                                    .foregroundStyle(Color.hex292929)
                                                Spacer()
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                }
                        }
                        //도착지 검색어 초기화 버튼
                        Button(action: {
                            mapVM.destination.name = ""
                            mapVM.routeInstruction = []
                            isFetched = false
                        }, label: {
                            Image(systemName: "x.circle")
                                .font(.system(size: 20))
                        })
                        .accessibilityLabel(Text("도착지 초기화 버튼"))
                    }
                }
                .padding(.bottom, 40)
                
                if !mapVM.isFetching && !isFetched && mapVM.routeInstruction == [] {
                    VStack {
                        Button(action: {
                            fetchRoute()
                        }, label: {
                            RoundedRectangle(cornerRadius: 25.5)
                                .frame(width: screenWidth * 0.85, height: 50)
                                .foregroundStyle(Color.hex246FFF)
                                .overlay {
                                    Text("길찾기")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.white)
                                }
                        })
                        .disabled(mapVM.isFetching)
                    }
                } else {
                    VStack {
                        if mapVM.isFetching {
                            Text("경로 찾는 중")
                        } else {
                            if mapVM.routeInstruction == [] {
                                Text("출발지와 도착지를 확인해주세요")
                            } else {
                                //경로 안내
                                VStack {
                                    HStack {
                                        Text("경로 안내")
                                            .font(.system(size: 17, weight: .semibold))
                                        Spacer()
                                        NavigationLink(destination: {
                                            MapView(mapVM: mapVM)
                                        }, label: {
                                                Text("지도 보기")
                                                .font(.system(size: 13))
                                                .foregroundStyle(Color.hex454545)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: 14)
                                                        .stroke(Color.hex292929, lineWidth: 0.5)
                                                }
                                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                        })
                                    }
                                    .frame(width: screenWidth * 0.86)
                                    ScrollView {
                                        HStack(spacing: 15) {
                                            Image("PathPal")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 15)
                                                .accessibilityHidden(true)
                                            Text(totalString)
                                            Spacer()
                                        }
                                        .font(.system(size: 15.5, weight: .medium))
                                        .padding(17)
                                        .background(Color.hexF4F8FF)
                                        VStack(alignment: .leading) {
                                            ForEach(mapVM.routeInstruction, id: \.self) { route in
                                                VStack(alignment: .leading) {
                                                    Text(route)
                                                        .font(.system(size: 14.5))
                                                }
                                                .padding(10)
                                                Divider()
                                                
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.bottom, 20)
                                    }
                                    .frame(width: screenWidth * 0.86, height: screenHeight * 0.4)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.hex959595.opacity(0.7), lineWidth: 0.7)
                                    }
                                }
                                .padding(.bottom)
                                
                                // 출발하기
                                VStack {
                                    NavigationLink(destination: {
                                        Compass(mapVM: mapVM)
                                    }, label: {
                                        RoundedRectangle(cornerRadius: 8)
                                            .frame(width: screenWidth * 0.86, height: 50)
                                            .foregroundStyle(Color.hex246FFF)
                                            .overlay {
                                                Text("출발하기")
                                                    .font(.system(size: 17, weight: .semibold))
                                                    .foregroundStyle(Color.white)
                                            }
                                    })
                                }
                            }
                        }
                    }
                    .padding(.top, -20)
                }
                Spacer()
            }
            .padding(.top, 60)
        }
    }
    
    func formatDistanceAndTime(distanceInMeters: Int, timeInSeconds: Int) -> String {
        let distance: String
        let time: String
        
        // 거리 변환: 1000 미터 이상일 경우 km로 표시, 아니면 m로 표시
        if distanceInMeters >= 1000 {
            distance = String(format: "%.2f km", Double(distanceInMeters) / 1000.0)
        } else {
            distance = "\(distanceInMeters)m"
        }
        
        // 시간 변환: 시간과 분으로 변환
        let hours = timeInSeconds / 3600
        let minutes = (timeInSeconds % 3600) / 60
        
        if hours > 0 {
            time = "\(hours)시간" + (minutes > 0 ? " \(minutes)분" : "")
        } else {
            time = "\(minutes)분"
        }
        
        return "총 거리: \(distance), 소요 시간: \(time)"
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
                mapVM.parseRouteCoordinates(routeResponse: data)
                mapVM.routeProperties = data.features[0].properties
                print("캐싱한 porperty 데이터", mapVM.routeProperties)
                mapVM.generateNavigationInstructions(response: data)
                totalString = formatDistanceAndTime(distanceInMeters: mapVM.routeProperties?.totalDistance ?? 0, timeInSeconds: mapVM.routeProperties?.totalTime ?? 0)
                isFetched = true
            })
            .store(in: &mapVM.cancellables)
    }
}

#Preview {
    NavigationPage(mapVM: MapViewModel())
}

//출발지 = 현재위치 코드

//                VStack(alignment: .leading) {
//                    Text("출발지")
//                        .font(.system(size: 17, weight: .semibold))
//                    RoundedRectangle(cornerRadius: 25.5)
//                        .stroke(Color.hexBBD2FF)
//                        .frame(width: screenWidth * 0.85, height: 50)
//                        .overlay {
//                            HStack {
//                                Text(mapVM.isLoading ? "현재 위치 설정 중" : "현재 위치를 출발지로 설정 완료")
//                                    .font(.system(size: 15, weight: mapVM.isLoading ? .regular : .medium))
//                                    .foregroundColor(mapVM.isLoading ? .hex959595 : .hex292929)
//                                Spacer()
//                            }
//                            .padding()
//                        }
//                }
//                .padding(.bottom)
