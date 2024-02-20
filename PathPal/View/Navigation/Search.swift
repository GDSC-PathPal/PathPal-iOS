//
//  Search.swift
//  PathPal
//
//  Created by Suji Lee on 1/7/24.
//

import SwiftUI
import Combine

struct SearchView: View {
    
    @ObservedObject var mapVM: MapViewModel
    @StateObject var speechService: SpeechService = SpeechService()
    enum FocusTextField: Hashable {
        case textField
    }
    @FocusState private var focusTextField: FocusTextField?
    
    @Environment(\.presentationMode) var presentationMode
    @State var query: String = ""
    @State var currentPage: Int = 1
    @State var resultArray: [PoiDetail] = []
    @State var responseArray: [PoiDetail] = []
    
    @Binding var searchMode: SearchMode
    @Binding var isStartingPointEqualsUserLocation: Bool
    
    @State var isShowingMic: Bool = false
    
    var body: some View {
        // 검색 페이지 뷰
        VStack {
            VStack {
                //검색창
                HStack {
                    Image(systemName: "magnifyingglass")
                        .padding(.trailing)
                        .accessibilityHidden(true)
                    TextField(searchMode == .startingPoint ? "출발지 입력" : "도착지 입력", text: $query, onCommit: {
                        self.searchByKeyword(query: self.query, page: 1)
                    })
                    .font(.system(size: 18))
                    .foregroundStyle(Color.hex959595)
                    .focused($focusTextField, equals: .textField)
//                    .accessibilityHint(Text(searchMode == .startingPoint ? "여기에 검색할 출발지를 입력하세요" : "여기에 검색할 도착지를 입력하세요"))
                    Spacer()
                    Button(action: {
                        self.searchByKeyword(query: self.query, page: 1)
                    }, label: {
                        Text("검색")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.hex246FFF)
                    })
                }
                .font(.system(size: 20))
                //구분선
                Rectangle()
                    .frame(width: screenWidth, height: 3)
                    .foregroundStyle(Color.hexEFEFEF)
                    .accessibilityHidden(true)
                //현위치 및 음성인식 버튼
                HStack {
                    //SearchMode == .startingPont 현위치 설정 버튼
                    if searchMode == .startingPoint {
                        Button(action: {
                            mapVM.startingPoint.noorLat = mapVM.userLocation.coordinate.latitude.description
                            mapVM.startingPoint.noorLon = mapVM.userLocation.coordinate.longitude.description
                            isStartingPointEqualsUserLocation = true
                            presentationMode.wrappedValue.dismiss()
                        }, label: {
                            HStack {
                                Image(systemName: "dot.scope")
                                Text("현위치")
                            }
                            .padding(7)
                        })
                        .frame(width: screenWidth * 0.45)
                    }
                    //음성 인식 버튼
                    Button(action: {
                        isShowingMic = true
                    }, label: {
                        HStack {
                            Image(systemName: "mic")
                            Text("음성 인식")
                        }
                        .padding(7)
                        
                    })
                    .frame(width: screenWidth * 0.45)
                }
                .foregroundStyle(Color.hex353535)
                //구분선
                Rectangle()
                    .frame(width: screenWidth, height: 1)
                    .foregroundStyle(Color.hexEFEFEF)
                    .accessibilityHidden(true)
            }
            .padding(13)
            .padding(.top, 15)
            //검색 결과 리스트
            List {
                ForEach(resultArray, id: \.self) { place in
                    VStack(alignment: .leading, spacing: 35) {
                        //카드 하나
                        HStack(spacing: 13) {
                            Rectangle()
                                .frame(width: 2.45, height: 64)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(place.name)
                                    .font(.system(size: 15.5, weight: .medium))
                                Text(place.roadName)
                                    .font(.system(size: 13.5))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onTapGesture {
                        mapVM.skResponse?.searchPoiInfo.totalCount = "0"
                        if searchMode == .startingPoint {
                            mapVM.startingPoint = place
                        } else {
                            mapVM.destination = place
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                if Int(mapVM.skResponse?.searchPoiInfo.totalCount ?? "") ?? 0 > resultArray.count {
                    Button(action: {
                        loadMoreResults()
                    }, label: {
                        RoundedRectangle(cornerRadius: 5)
                            .frame(width: screenWidth * 0.95, height: 55)
                            .foregroundColor(.clear)
                            .overlay (
                                Text("검색 결과 더보기")
                                    .font(.system(size: 15.5, weight: .medium))
                            )
                    })
                }
            }
            .listStyle(PlainListStyle())
        }
        .overlay {
            // 음성 녹음 마이크 뷰 (overlay)
            if isShowingMic {
                MicRecordView(query: $query, isShowingMic: $isShowingMic)
            }
        }
        .onAppear {
            if searchMode == .startingPoint {
                isStartingPointEqualsUserLocation = false
                mapVM.initStartingPoint()
            } else {
                mapVM.initDestination()
            }
            self.focusTextField = .textField
        }
        .onDisappear {
            resultArray.removeAll()
        }
    }
    
    func loadMoreResults() {
        currentPage += 1
        mapVM.requestKeywordDataToSK(query: query, longitude: String(format: "%.6f", mapVM.userLocation.coordinate.longitude), latitude: String(format: "%.6f", mapVM.userLocation.coordinate.latitude), page: currentPage)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print("키워드 검색 비동기 error : \(error)")
                case .finished:
                    break
                }
            }, receiveValue: { pois in
                self.responseArray = pois
                resultArray.append(contentsOf: responseArray)
            })
            .store(in: &mapVM.cancellables)
    }
    
    func searchByKeyword(query: String, page: Int) {
        mapVM.isSearching = true
        mapVM.requestKeywordDataToSK(query: query, longitude: String(format: "%.6f", mapVM.userLocation.coordinate.longitude), latitude: String(format: "%.6f", mapVM.userLocation.coordinate.latitude), page: page)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print("키워드 검색 비동기 error : \(error)")
                case .finished:
                    break
                }
            }, receiveValue: { pois in
                resultArray.removeAll()
                mapVM.routeInstruction?.removeAll()
                self.resultArray = pois
            })
            .store(in: &mapVM.cancellables)
    }
}

#Preview {
    SearchView(mapVM: MapViewModel(), searchMode: .constant(SearchMode.startingPoint), isStartingPointEqualsUserLocation: .constant(true))
}
