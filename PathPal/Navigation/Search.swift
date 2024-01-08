//
//  Search.swift
//  PathPal
//
//  Created by Suji Lee on 1/7/24.
//

import SwiftUI
import Combine

let TMAP_APP_KEY = Bundle.main.object(forInfoDictionaryKey: "TMAP_APP_KEY") as? String ?? ""

struct Meta: Codable, Hashable {
    var isEnd: Bool?
    var pageableCount: Int?
    var totalCount: Int?
    var sameName: SameName?
    
    enum CodingKeys: String, CodingKey {
        case isEnd = "is_end"
        case pageableCount = "pageable_count"
        case totalCount = "total_count"
        case sameName = "same_name"
    }
    
    struct SameName: Codable, Hashable {
        var region: [String]?
        var keyword: String?
        var selectedRegion: String?
        
        enum CodingKeys: String, CodingKey {
            case region = "region"
            case keyword = "keyword"
            case selectedRegion = "selected_region"
        }
    }
}

struct SearchView: View {
    
    @ObservedObject var mapVM: MapViewModel
    
    enum FocusTextField: Hashable {
        case textField
    }
    @FocusState private var focusTextField: FocusTextField?
    
    @Environment(\.presentationMode) var presentationMode
    @State var query: String = ""
    @State var currentPage: Int = 1
    @State var resultArray: [PoiDetail] = []
    @State var responseArray: [PoiDetail] = []
    
    var body: some View {
        VStack {
            VStack {
                //검색창
                HStack {
                    Image(systemName: "magnifyingglass")
                        .padding(.trailing)
                    TextField("도착지 입력", text: $query)
                        .font(.system(size: 18))
                        .foregroundStyle(Color.hex959595)
                        .focused($focusTextField, equals: .textField)
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
                    .frame(width: screenWidth, height: 1)
                    .foregroundStyle(Color.hexEFEFEF)
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
                        mapVM.destination = place
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
        .onAppear {
            self.focusTextField = .textField
        }
    }
    
    func loadMoreResults() {
            mapVM.requestKeywordDataToSK(query: query, longitude: String(format: "%.6f", mapVM.userLocation.coordinate.longitude), latitude: String(format: "%.6f", mapVM.userLocation.coordinate.latitude), page: currentPage)
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        print("키워드 검색 비동기 error : \(error)")
                    case .finished:
                        print("키워드 검색 비동기 성공")
                        break
                    }
                }, receiveValue: { pois in
                    self.responseArray = pois
                    resultArray.append(contentsOf: responseArray)
                })
                .store(in: &mapVM.cancellables)
            currentPage += 1
        
    }
    
    func searchByKeyword(query: String, page: Int) {
        mapVM.isSearching = true
        mapVM.requestKeywordDataToSK(query: query, longitude: String(format: "%.6f", mapVM.userLocation.coordinate.latitude), latitude: String(format: "%.6f", mapVM.userLocation.coordinate.longitude), page: page)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print("키워드 검색 비동기 error : \(error)")
                case .finished:
                    print("키워드 검색 비동기 성공")
                    break
                }
            }, receiveValue: { pois in
                print("pois?", pois)
                    resultArray.removeAll()
                    self.resultArray = pois
                print("searchByKeyword 함수의 resultArray", resultArray)

                
            })
            .store(in: &mapVM.cancellables)
    }
}
