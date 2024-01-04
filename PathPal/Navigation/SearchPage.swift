//
//  SearchPage.swift
//  PathPal
//
//  Created by Suji Lee on 12/26/23.
//

import SwiftUI

struct SearchPage: View {
    enum FocusTextField: Hashable {
       case textField
     }
    @FocusState private var focusTextField: FocusTextField?
    
    @State var query: String = ""
    
    var body: some View {
        VStack {
            // 검색창
            HStack {
                TextField("도착지 입력", text: $query)
                    .frame(height: 55)
                    .foregroundStyle(Color.hex959595)
                    .font(.system(size: 18))
                    .focused($focusTextField, equals: .textField)
                    .onChange(of: query, perform: { newValue in
                        searchByKeyword(query: newValue, page: 1)
                        print(newValue)
                    })
                Spacer()
                Button(action: {
                    query = ""
                }, label: {
                    Image(systemName: "x.circle.fill")
                        .foregroundStyle(Color.hex959595)
                        .font(.system(size: 15))
                })
            }
            // 구분선
            Rectangle()
                .frame(height: 3)
                .foregroundStyle(Color.hexEFEFEF)
            
            // 검색 결과 목록
        }
    }
    
    func searchByKeyword(query: String, page: Int) {
//        mapVM.isSearcing = true
//        if let token = try? TokenManager.shared.getToken() {
//            mapVM.requestKeywordDataToKakao(accessToken: token, query: query, longitude: String(format: "%.6f", region.center.latitude), latitude: String(format: "%.6f", region.center.longitude), page: page)
//                .sink(receiveCompletion: { completion in
//                    switch completion {
//                    case .failure(let error):
//                        print("키워드 검색 비동기 error : \(error)")
//                    case .finished:
//                        print("키워드 검색 비동기 성공")
//                        break
//                    }
//                }, receiveValue: { keywords in
//                    DispatchQueue.main.async {
//                        resultArray.removeAll()
//                        self.resultArray = keywords.map { cafe in
//                            CafePlace(id: cafe.id, addressName: cafe.addressName, phone: cafe.phone, placeName: cafe.placeName, roadAddressName: cafe.roadAddressName, x: cafe.x, y: cafe.y)
//                        }
//                    }
//                })
//                .store(in: &mapVM.cancellables)
//        }
    }
}

#Preview {
    SearchPage()
}
