//
//  MapModel.swift
//  PathPal
//
//  Created by Suji Lee on 1/23/24.
//

import Foundation
import SwiftUI
import CoreLocation
import Combine

// Main response structure
struct SKResponse: Codable {
    var searchPoiInfo: SearchPoiInfo
}

struct SearchPoiInfo: Codable {
    var totalCount: String
    var count: String
    var page: String
    var pois: Pois
}

struct Pois: Codable {
    var poi: [PoiDetail]
}

struct PoiDetail: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var telNo: String?
    var frontLat: String?
    var frontLon: String?
    var noorLat: String?
    var noorLon: String?
    var upperAddrName: String?
    var middleAddrName: String?
    var lowerAddrName: String?
    var detailAddrname: String?  // Make this optional
    var mlClass: String = ""
    var firstNo: String = ""
    var secondNo: String = ""
    var roadName: String = ""
    var firstBuildNo: String = ""
    var secondBuildNo: String = ""
    var radius: String = ""
    var upperBizName: String = ""
    var middleBizName: String = ""
    var lowerBizName: String = ""
    var detailBizName: String?
    var zipCode: String?
    var evChargers: EVChargers?
    var groupSubLists: GroupSubLists?
    var newAddressList: NewAddressList?
}

struct EVChargers: Codable, Hashable {
    var evCharger: [EVChargerDetail] = []
}

struct EVChargerDetail: Codable, Hashable {
    var operatorId: String = ""
    var stationId: String = ""
    var chargerId: String = ""
    var status: String = ""
    var type: String = ""
    var powerType: String = ""
    var operatorName: String = ""
    var chargingDateTime: String = ""
    var updateDateTime: String = ""
    var isFast: String = ""
    var isAvailable: String = ""
}

struct GroupSubLists: Codable, Hashable {
    var groupSub: [GroupSubDetail] = []
}

struct GroupSubDetail: Codable, Hashable {
    var subPkey: String = ""
    var subSeq: String = ""
    var subName: String = ""
    var subCenterY: String = ""
    var subCenterX: String = ""
    var subNavY: String = ""
    var subNavX: String = ""
    var subRpFlag: String = ""
    var subPoiId: String = ""
    var subNavSeq: String = ""
    var subParkYn: String = ""
    var subClassCd: String = ""
    var subClassNmA: String = ""
    var subClassNmB: String = ""
    var subClassNmC: String = ""
    var subClassNmD: String = ""
}

struct NewAddressList: Codable, Hashable {
    var newAddress: [NewAddressDetail] = []
}

struct NewAddressDetail: Codable, Hashable {
    var centerLat: String = ""
    var centerLon: String = ""
    var frontLat: String = ""
    var frontLon: String = ""
    var roadName: String = ""
    var bldNo1: String = ""
    var bldNo2: String = ""
    var roadId: String = ""
    var fullAddressRoad: String = ""
}

// Define structures to model the JSON response
struct RouteResponse: Codable {
    let type: String
    let features: [Feature]
}

struct Feature: Codable {
    let type: String
    let geometry: Geometry
    let properties: Properties
}

struct Geometry: Codable {
    let type: String
    let coordinates: Coordinates

    enum Coordinates {
        case point([Double])
        case lineString([[Double]])
    }

    enum CodingKeys: String, CodingKey {
        case type, coordinates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)

        if type == "Point" {
            let coordinateData = try container.decode([Double].self, forKey: .coordinates)
            coordinates = .point(coordinateData)
        } else if type == "LineString" {
            let coordinateData = try container.decode([[Double]].self, forKey: .coordinates)
            coordinates = .lineString(coordinateData)
        } else {
            throw DecodingError.dataCorruptedError(forKey: .type,
                                                  in: container,
                                                  debugDescription: "Invalid type for coordinates")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        switch coordinates {
        case .point(let coordinateData):
            try container.encode(coordinateData, forKey: .coordinates)
        case .lineString(let coordinateData):
            try container.encode(coordinateData, forKey: .coordinates)
        }
    }
}

struct Properties: Codable {
    let totalDistance: Int?
    let totalTime: Int?
    let index: Int
    let pointIndex: Int?
    let name: String?
    let description: String?
    let direction: String?
    let nearPoiName: String?
    let nearPoiX: String?
    let nearPoiY: String?
    let intersectionName: String?
    let facilityType: String?
    let facilityName: String?
    let turnType: Int?
    let pointType: String?
    
    // LineString properties
    let lineIndex: Int?
    let distance: Int?
    let time: Int?
    let roadType: Int?
    let categoryRoadType: Int?
}

