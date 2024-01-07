//
//  Search.swift
//  PathPal
//
//  Created by Suji Lee on 1/7/24.
//

import SwiftUI
import Combine

let KAKAO_REST_API_KEY = Bundle.main.object(forInfoDictionaryKey: "KAKAO_REST_API_KEY") as? String ?? ""

struct KakaoResponse: Codable, Hashable {
    var meta: Meta?
    var documents: Array<Place>?
}

struct Place: Codable, Hashable, Identifiable {
    var addressName: String = ""
    var categoryGroupCode: String = ""
    var categoryGroup_name: String = ""
    var category_name: String = ""
    var distance: String = ""
    var id: String = ""
    var phone: String = ""
    var placeName: String = ""
    var placeUrl: String = ""
    var roadAddressName: String = ""
    var x: String = ""
    var y: String = ""
    
    enum CodingKeys: String, CodingKey {
        case addressName = "address_name"
        case categoryGroupCode = "category_group_code"
        case categoryGroup_name = "category_group_name"
        case category_name = "category_name"
        case distance = "distance"
        case id = "id"
        case phone = "phone"
        case placeName = "place_name"
        case placeUrl = "place_url"
        case roadAddressName = "road_address_name"
        case x = "x"
        case y = "y"
    }
}

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

class MapViewModel: NSObject, ObservableObject {
    @Published var keywordKakaoResponse: KakaoResponse?
    @Published var keywordPlaces: [Place] = []
    
    @Published var targetPlace: Place = Place()
    
    @Published var isSearching: Bool = false
    
    var extractedMapIds: [String] = []
    
    var cancellables = Set<AnyCancellable>()
    
    //좌표는 소수점 6번째까지
    func requestKeywordDataToKakao(query: String, longitude: String, latitude: String, page: Int) -> Future<[Place], Error> {
        return Future { promise in
            var query = query
            let targetUrl = "https://dapi.kakao.com/v2/local/search/keyword.json?page=\(page)&size=15&sort=distance&query=\(query)&x=\(latitude)&y=\(longitude)&radius=20000"
            let encodedUrl = targetUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            
            guard let url = URL(string: encodedUrl) else {
                fatalError("Invalid URL")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("KakaoAK \(KAKAO_REST_API_KEY)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTaskPublisher(for: request)
                .map { $0.data }
                .decode(type: KakaoResponse.self, decoder: JSONDecoder())
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        print("Failed to search places: \(error)")
                    case .finished:
                        promise(.success(self.keywordPlaces))
                        print("search success")
                        break
                    }
                }, receiveValue: { data in
                    self.keywordKakaoResponse = data
                    self.keywordPlaces = data.documents ?? []
                })
                .store(in: &self.cancellables)
        }
    }
}

struct SearchView: View {
    
    enum FocusTextField: Hashable {
        case textField
    }
    @FocusState private var focusTextField: FocusTextField?
    
    @Environment(\.presentationMode) var presentationMode
    @StateObject var mapVM: MapViewModel = MapViewModel()
    //    @Binding var currentMode: CurrentMode
    @State var query: String = ""
    @State var currentPage: Int = 1
    @State var resultArray: [Place] = []
    @State var targetPlace: Place = Place()
    
    var body: some View {
        VStack {
            VStack {
                //검색창
                HStack {
                    Image(systemName: "magnifyingglass")
                        .padding(.trailing)
                    TextField("카페명, 지점명으로 검색", text: $query)
                        .font(.system(size: 18))
                        .focused($focusTextField, equals: .textField)
                    
                    Spacer()
                    Button(action: {
                        query = ""
                    }, label: {
                        Image(systemName: "x.circle.fill")
                            .font(.system(size: 15))
                    })
                    
                    Button("Search") {
                        // Initiating search when the user presses this button
                        self.searchByKeyword(query: self.query, page: 1)
                    }
                }
                .font(.system(size: 20))
                //구분선
                Rectangle()
                    .frame(width: screenWidth, height: 1)
            }
            .padding(13)
            .padding(.top, 15)
            //검색 결과 리스트
            List {
                ForEach(resultArray.filter { "\($0)".contains(self.query) || self.query.isEmpty }) { place in
                    VStack(alignment: .leading, spacing: 35) {
                        //카드 하나
                        HStack(spacing: 13) {
                            Rectangle()
                                .frame(width: 2.45, height: 64)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(place.placeName)
                                    .font(.system(size: 15.5, weight: .medium))
                                
                                Text(place.roadAddressName)
                                    .font(.system(size: 13.5))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onTapGesture {
                        targetPlace = place
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                if let isEnd = mapVM.keywordKakaoResponse?.meta?.isEnd, isEnd == false && !resultArray.isEmpty {
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
        if let isEnd = mapVM.keywordKakaoResponse?.meta?.isEnd, isEnd == false {
            mapVM.requestKeywordDataToKakao(query: query, longitude: String(format: "%.6f", userLocation.coordinate.longitude), latitude: String(format: "%.6f", userLocation.coordinate.latitude), page: currentPage)
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        print("키워드 검색 비동기 error : \(error)")
                    case .finished:
                        print("키워드 검색 비동기 성공")
                        break
                    }
                }, receiveValue: { data in
                    let keywokdArray = data.map { cafe in
                        Place(addressName: cafe.addressName, id: cafe.id, placeName: cafe.placeName, roadAddressName: cafe.roadAddressName, x: cafe.x, y: cafe.y)
                    }
                    resultArray.append(contentsOf: keywokdArray)
                })
                .store(in: &mapVM.cancellables)
            currentPage += 1
        }
    }
    
    func searchByKeyword(query: String, page: Int) {
        mapVM.isSearching = true
        mapVM.requestKeywordDataToKakao(query: query, longitude: String(format: "%.6f", userLocation.coordinate.latitude), latitude: String(format: "%.6f", userLocation.coordinate.longitude), page: page)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure(let error):
                    print("키워드 검색 비동기 error : \(error)")
                case .finished:
                    print("키워드 검색 비동기 성공")
                    break
                }
            }, receiveValue: { keywords in
                print(keywords)
                DispatchQueue.main.async {
                    resultArray.removeAll()
                    self.resultArray = keywords.map { cafe in
                        Place(addressName: cafe.addressName, id: cafe.id, placeName: cafe.placeName, roadAddressName: cafe.roadAddressName, x: cafe.x, y: cafe.y)
                    }
                }
            })
            .store(in: &mapVM.cancellables)
        
    }
}
