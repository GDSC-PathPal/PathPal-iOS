//
//  SearchModel.swift
//  PathPal
//
//  Created by Suji Lee on 1/23/24.
//

import Foundation

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
