//
//  MapViewModel.swift
//  PathPal
//
//  Created by Suji Lee on 1/23/24.
//

import Foundation
import SwiftUI
import CoreLocation
import Combine
import GoogleMaps

let TMAP_APP_KEY = Bundle.main.object(forInfoDictionaryKey: "TMAP_APP_KEY") as? String ?? ""

class MapViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userLocation: CLLocation = CLLocation(latitude: 2.111111, longitude: 2.111111)
    @Published var userHeading: CLLocationDirection = CLLocationDirection()
    
    @Published var destination: PoiDetail = PoiDetail(id: "", name: "")
    @Published var startingPoint: PoiDetail = PoiDetail(id: "", name: "")
    @Published var skResponse: SKResponse?
    
    @Published var isFetching: Bool = false
    @Published var hassucceededFetching: Bool = false
    @Published var isSearching: Bool = false
    
    @Published var routeProperties: Properties?
    
    @Published var extractedMapIds: [String] = []
    @Published var routeInstruction: [String]?
    
    @Published var wayPointArray: [WayPoint] = []
    
    var cancellables = Set<AnyCancellable>()
    
    //지도에 표시될 마커들
    @Published var coordinatesForMap: [CLLocationCoordinate2D] = []

    //올바른 출발 방향 관련 변수
    @Published var startHeading: Double?
    @Published var isHeadingRightDirection: Bool = false
    @Published var hasTriggeredHapticFeedback: Bool = false

    private let locationManager = CLLocationManager()
    @Published var lastLocation: CLLocation?
    @Published var isLoading = true  // Tracks if the location is being loaded initially
    var bearing: CLLocationDirection = 0 // Holds the latest heading/bearing
//    var mapView: GMSMapView?
    
    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.startUpdatingLocation()
        self.locationManager.startUpdatingHeading()  // Start receiving heading updates
    }
    
    func initStartingPoint() {
        self.startingPoint = PoiDetail(id: "", name: "")
        self.routeInstruction = nil
    }
    
    func initDestination() {
        self.destination = PoiDetail(id: "", name: "")
        self.routeInstruction = nil
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            lastLocation = location
            userLocation = location  // 사용자의 최신 위치 업데이트
            
            // 출발지 좌표 업데이트
            startingPoint.noorLon = String(format: "%.6f", location.coordinate.longitude)
            startingPoint.noorLat = String(format: "%.6f", location.coordinate.latitude)
            isLoading = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        bearing = newHeading.trueHeading != -1 ? newHeading.trueHeading : newHeading.magneticHeading
        userHeading = bearing // 사용자의 최신 헤딩 업데이트
        
        let startHeadingValue = startHeading ?? 0  // 옵셔널 처리
        let adjustedStartHeading = startHeadingValue.truncatingRemainder(dividingBy: 360)  // 0~359 범위로 조정
        let adjustedUserHeading = userHeading.truncatingRemainder(dividingBy: 360)  // 0~359 범위로 조정

        // 오차 범위 내에서 방향이 일치하는지 확인 (예: 오차 범위를 20도로 설정)
        if adjustedUserHeading.isClose(to: adjustedStartHeading, within: 8) {
            isHeadingRightDirection = true
        } else {
            isHeadingRightDirection = false
        }
//        print("adjustedUserHeading", adjustedUserHeading)
//        print("adjustedStartHeading", adjustedStartHeading)
//        print("올바른 방향 가리킴 : ", isHeadingRightDirection)
    }

    func requestKeywordDataToSK(query: String, longitude: String, latitude: String, page: Int) -> Future<[PoiDetail], Error> {
        return Future { promise in
            let targetUrl = "https://apis.openapi.sk.com/tmap/pois?version=1&searchKeyword=\(query)&searchType=all&page=\(page)&count=15&resCoordType=WGS84GEO&multiPoint=N&searchtypCd=R&radius=0&reqCoordType=WGS84GEO&poiGroupYn=N&centerLon=\(longitude)&centerLat=\(latitude)"
            

            let encodedUrl = targetUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!

            guard let url = URL(string: encodedUrl) else {
                fatalError("Invalid URL")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("\(TMAP_APP_KEY)", forHTTPHeaderField: "appKey")
            URLSession.shared.dataTaskPublisher(for: request)
                .tryMap { output in
                    guard let response = output.response as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }
                    
                    print("HTTP Status Code: \(response.statusCode)")
                    
                    guard response.statusCode == 200 else {
                        throw URLError(.badServerResponse)
                    }
                    
                    return output.data
                }
                .decode(type: SKResponse.self, decoder: JSONDecoder())
                .receive(on: DispatchQueue.main)
                .catch { error -> AnyPublisher<SKResponse, Error> in
                    if let urlError = error as? URLError {
                        self.hassucceededFetching = false
                        print("Error Code: \(urlError.errorCode)")
                        print("Error Message: \(urlError.localizedDescription)")
                    } else {
                        print("Unknown error: \(error)")
                    }
                    return Fail(error: error).eraseToAnyPublisher()
                }
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        print("Failed to search places: \(error)")
                        promise(.failure(error))
                    case .finished:
                        break
                    }
                }, receiveValue: { data in
//                    print("검색결과 : ", data)
                    self.skResponse = data
                    promise(.success(data.searchPoiInfo.pois.poi))
                    
                })
                .store(in: &self.cancellables)
        }
    }
    
    func fetchRoute(parameters: [String: Any]) -> AnyPublisher<RouteResponse, Error> {
        self.isFetching = true
        self.hassucceededFetching = false
        let url = URL(string: "https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1&callback=function")!
        let headers = [
            "accept": "application/json",
            "content-type": "application/json",
            "appKey": "\(TMAP_APP_KEY)"  // Replace TMAP_APP_KEY with your actual app key
        ]
        
        // Convert parameters to JSON data
        guard let postData = try? JSONSerialization.data(withJSONObject: parameters, options: []) else {
            fatalError("Invalid parameters")
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers
        request.httpBody = postData
        
        // Make the request and decode the response
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { output in
                guard let response = output.response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                print("HTTP Status Code: \(response.statusCode)")
                
                guard response.statusCode == 200 else {
                    throw URLError(.badServerResponse)
                }
                
                return output.data
            }
            .decode(type: RouteResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .catch { error -> AnyPublisher<RouteResponse, Error> in
                if let urlError = error as? URLError {
                    self.hassucceededFetching = false
                    print("Error Code: \(urlError.errorCode)")
                    print("Error Message: \(urlError.localizedDescription)")
                } else {
                    print("Unknown error: \(error)")
                }
                self.hassucceededFetching = false
                self.routeInstruction = []
                self.isFetching = false
                return Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    func generateNavigationInstructions(response: RouteResponse) {
        var instructions: [String] = []
    
        for feature in response.features {
            if feature.geometry.type == "Point" {
                if let description = feature.properties.description {
                    instructions.append(formatInstruction(description: description, turnType: feature.properties.turnType ?? 0))
                }
            }
        }
        self.routeInstruction = instructions
    }
    
    func formatInstruction(description: String, turnType: Int) -> String {
        var instruction = description

        // ~로 을
        if instruction.contains("로 을") {
            instruction = instruction.replacingOccurrences(of: "로 을", with: "로를")
        }
        // 횡단보도 관련 문자열 예외처리
        if instruction.contains("횡단보도 후") {
            instruction = instruction.replacingOccurrences(of: "횡단보도 후", with: "횡단보도를 건넌 후")
        }
        switch turnType {
        case 11:
             return "직진, \(instruction)"
        case 12:
            return "좌회전, \(instruction)"
        case 13:
            return "우회전, \(instruction)"
        case 14:
            return "유턴, \(instruction)"
        case 16:
            return "8시 방향으로 좌회전, \(instruction)"
        case 17:
            return "10시 방향으로 좌회전, \(instruction)"
        case 18:
            return "2시 방향으로 우회전, \(instruction)"
        case 19:
            return "4시 방향으로 우회전, \(instruction)"
        case 125:
            return "육교 건너기, \(instruction)"
        case 126:
            return "지하보도를 건너기, \(instruction)"
        case 127:
            return "계단 진입, \(instruction)"
        case 128:
            return "경사로 진입, \(instruction)"
        case 129:
            return "계단과 경사로 진입, \(instruction)"
        case 184:
            return "경유지, \(instruction)"
        case 185...189:
            return "경유지, \(instruction)"
        case 200:
            return "출발지에서 직진, \(instruction)"
        case 201:
            return "목적지 도착"
        case 211:
            return "횡단보도 건너기, \(instruction)"
        case 212:
            return "좌측 횡단보도 건너기, \(instruction)"
        case 213:
            return "우측 횡단보도 건너기, \(instruction)"
        case 214:
            return "8시 방향 횡단보도 건너기, \(instruction)"
        case 215:
            return "10시 방향 횡단보도 건너기, \(instruction)"
        case 216:
            return "2시 방향 횡단보도 건너기, \(instruction)"
        case 217:
            return "4시 방향 횡단보도 건너기, \(instruction)"
        case 218:
            return "엘리베이터 이용, \(instruction)"
        case 233:
            return "직진, \(instruction)"
        default:
            // 방향 정보가 없는 경우에는 직진으로 간주
            if description.contains("이동") {
                instruction = "출발지에서 직진 \(instruction)"
            }
        }
        return instruction
    }

    func directionDescription(from turnType: Int) -> String {
                switch turnType {
                case 1...7:
                    return "안내 없음"
                case 11:
                    return "직진"
                case 12:
                    return "좌회전"
                case 13:
                    return "우회전"
                case 14:
                    return "유턴"
                case 16:
                    return "8시 방향 좌회전"
                case 17:
                    return "10시 방향 좌회전"
                case 18:
                    return "2시 방향 우회전"
                case 19:
                    return "4시 방향 우회전"
                case 125:
                    return "육교"
                case 126:
                    return "지하보도"
                case 127:
                    return "계단 진입"
                case 128:
                    return "경사로 진입"
                case 129:
                    return "계단+경사로 진입"
                case 184:
                    return "경유지"
                case 185:
                    return "첫 번째 경유지"
                case 186:
                    return "두 번째 경유지"
                case 187:
                    return "세 번째 경유지"
                case 188:
                    return "네 번째 경유지"
                case 189:
                    return "다섯 번째 경유지"
                case 200:
                    return "출발지"
                case 201:
                    return "목적지"
                case 211:
                    return "횡단보도"
                case 212:
                    return "좌측 횡단보도"
                case 213:
                    return "우측 횡단보도"
                case 214:
                    return "8시 방향 횡단보도"
                case 215:
                    return "10시 방향 횡단보도"
                case 216:
                    return "2시 방향 횡단보도"
                case 217:
                    return "4시 방향 횡단보도"
                case 218:
                    return "엘리베이터"
                case 233:
                    return "임시 직진"
                default:
                    return ""
                }
    }

    func roadTypeDescription(from roadType: Int?) -> String {
        switch roadType {
            case 21: return "차도와 인도가 분리되어 있으며, 정해진 횡단구역으로만 횡단 가능한 보행자 도로"
            case 22: return "차도와 인도가 분리되어 있지 않거나, 보행자 횡단에 제약이 없는 보행자 도로"
            case 23: return "차량 통행이 불가능한 보행자도로"
            case 24: return "쾌적하지 않은 도로"
        default: return ""
        }
    }
    
    func facilityDescription(from facilityType: String?) -> String {
        switch facilityType {
        case "1": return "교량"
            case "2": return "터널"
            case "3": return "고가도로"
            case "11": return "일반보행자도로"
            case "12": return "육교"
            case "14": return "지하보도"
            case "15": return "횡단보도"
            case "16": return "대형시설물이동통로"
            case "17": return "계단"
        default: return ""

        }
    }
    
    func updateMapWithRoute() {
        print("updateMapWithRoute함수가 불릴 때 wayPonritArray 요소 개수 : ", wayPointArray.count)
        // `wayPointArray`의 첫 번째와 두 번째 요소를 사용하여 방향 계산
        if wayPointArray.count >= 2 {
            let startWayPoint = wayPointArray[0]
            let nextWayPoint = wayPointArray[1]
            
            // `CLLocationCoordinate2D` 타입으로 변환
            let startLocation = CLLocationCoordinate2D(latitude: startWayPoint.latitude ?? 0, longitude: startWayPoint.longitude ?? 0)
            let nextLocation = CLLocationCoordinate2D(latitude: nextWayPoint.latitude ?? 0, longitude: nextWayPoint.longitude ?? 0)
            
            // 방향 계산
            startHeading = calculateBearing(from: startLocation, to: nextLocation)
        }
    }
    
    func extractWayPoints(from routeResponse: RouteResponse){
        let features = routeResponse.features

        for (index, feature) in features.enumerated() {
            if feature.geometry.type == "Point", index + 1 < features.count, features[index + 1].geometry.type == "LineString" {
                let wayPoint = combinePointAndLineStringFeatures(pointFeature: feature, lineStringFeature: features[index + 1])
                self.wayPointArray.append(wayPoint)
            }
        }
        if wayPointArray.count >= 2 {
            self.updateMapWithRoute()
        }
        print("경유지 배열!", self.wayPointArray)
    }
    
    //실시간 안내를 위한 웨이포인트
    func combinePointAndLineStringFeatures(pointFeature: Feature, lineStringFeature: Feature) -> WayPoint {
        // 'Point' 타입 Feature의 좌표
        let pointCoordinates: [Double] = {
            if case let .point(coordinates) = pointFeature.geometry.coordinates {
                return coordinates
            } else {
                return [0.0, 0.0]  // 기본값, 실제 사용시 적절한 오류 처리 필요
            }
        }()
        
        let longitude = pointCoordinates[0]
        let latitude = pointCoordinates[1]

        // 'Point' 타입 Feature에서 정보 추출
        let pointName = pointFeature.properties.name ?? "Unknown"
        let pointDescription = pointFeature.properties.description ?? ""
        let pointTurnType = pointFeature.properties.turnType ?? 0
        let pointFacilityType = pointFeature.properties.facilityType ?? ""

        // 'LineString' 타입 Feature에서 정보 추출
        let lineStringRoadType = lineStringFeature.properties.roadType ?? 0
        let lineStringTime = lineStringFeature.properties.time ?? 0

        return WayPoint(
            longitude: longitude,
            latitude: latitude,
            name: pointName,
            description: pointDescription,
            turnType: pointTurnType.description,
            facilityType: pointFacilityType.description,
            roadType: lineStringRoadType.description,
            time: lineStringTime.description
        )
    }
}

extension MapViewModel {
    func extractCoordinatesFromRoute(route: RouteResponse) -> [CLLocationCoordinate2D] {
        var coordinates = [CLLocationCoordinate2D]()
        
        for feature in route.features {
            if feature.geometry.type == "Point",
               let point = feature.geometry.coordinates as? [Double],
               point.count == 2 {
                let coordinate = CLLocationCoordinate2D(latitude: point[1], longitude: point[0])
                coordinates.append(coordinate)
            }
        }
        
        return coordinates
    }

    func displayMarkersOnMap(coordinates: [CLLocationCoordinate2D], mapView: GMSMapView) {
        for coordinate in coordinates {
            let marker = GMSMarker(position: coordinate)
            marker.map = mapView
        }
    }

    func parseRouteCoordinates(routeResponse: RouteResponse) {
        var routeCoordinates: [CLLocationCoordinate2D] = []

        for feature in routeResponse.features {
            switch feature.geometry.coordinates {
            case .lineString(let lineCoordinates):
                for coordinatePair in lineCoordinates {
                    let coordinate = CLLocationCoordinate2D(latitude: coordinatePair[1], longitude: coordinatePair[0])
                    routeCoordinates.append(coordinate)
                }
            default:
                break // 'Point' 타입의 좌표는 무시합니다.
            }
        }

        self.coordinatesForMap = routeCoordinates
    }
    
    func calculateBearing(from start: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude.toRadians()
        let lon1 = start.longitude.toRadians()

        let lat2 = destination.latitude.toRadians()
        let lon2 = destination.longitude.toRadians()

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)

        // radiansBearing을 도(degree) 단위로 변환한 후, 음수일 경우 360을 더하여 양수로 조정
        var degreesBearing = radiansBearing.toDegrees()
        if degreesBearing < 0 {
            degreesBearing += 360
        }

        return degreesBearing
    }
}

extension Double {
    func toRadians() -> Double {
        return self * .pi / 180.0
    }
    func toDegrees() -> Double {
        return self * 180.0 / .pi
    }
    func isClose(to other: Double, within delta: Double) -> Bool {
        return abs(self - other) <= delta
    }
}
