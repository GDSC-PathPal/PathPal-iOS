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
    
    private var speechService: SpeechService = SpeechService()
    
    @Published var userLocation: CLLocation = CLLocation()
    
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
    
    @Published var hasArrived: Bool = false
    
    @Published var currentWayPointIndex: Int = 0
    @Published var resultString: String = ""
    
    var cancellables = Set<AnyCancellable>()
    
    //지도에 표시될 마커들
    @Published var coordinatesForMap: [CLLocationCoordinate2D] = []
    
    //올바른 출발 방향 관련 변수
    var directionAdjustValue: Double = 20
    @Published var userHeading: CLLocationDirection = CLLocationDirection()
    @Published var startDirection: CLLocationDirection = CLLocationDirection()
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
        guard let location = locations.last else { return }
        lastLocation = location
        userLocation = location  // 사용자의 최신 위치 업데이트
        if let destinationLon = self.destination.noorLon, let destinationLat = self.destination.noorLat {
            let userLocation = CLLocation(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
            let destinationLocation = CLLocation(latitude: Double(destinationLat) ?? 0.0, longitude: Double(destinationLon) ?? 0.0)

            let distance = userLocation.distance(from: destinationLocation) // 두 지점 사이의 거리를 미터 단위로 계산

            if distance <= 50 && !hasArrived { // 1.5미터 이내의 오차를 허용
                speechService.speak(text: "목적지에 도착했습니다")
                self.hasArrived = true
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        userHeading = newHeading.trueHeading - directionAdjustValue
        
        if isCorrectDirection(bearing: startDirection, heading: userHeading) {
            isHeadingRightDirection = true
        }
        
        print("현재 방향 : ", userHeading)
        print("출발 방향 : ", startDirection)
        print(isHeadingRightDirection)
    }
    
    func isCorrectDirection(bearing: CLLocationDirection, heading: CLLocationDirection) -> Bool {
        // 두 방향 간의 차이를 계산합니다. 결과는 -360 ~ 360도 사이의 값이 될 수 있습니다.
        let difference = bearing - heading
        
        // 차이를 -180 ~ 180도 범위로 정규화합니다.
        let normalizedDifference = (difference + 180).truncatingRemainder(dividingBy: 360) - 180
        
        // 정규화된 차이의 절대값이 5도 이내인지 확인합니다.
        return abs(normalizedDifference) <= 5
    }

    
    func updateMapWithRoute() {
        if wayPointArray.count >= 2 {
            let startLocation = CLLocationCoordinate2D(latitude: wayPointArray[0].latitude ?? 0, longitude: wayPointArray[0].longitude ?? 0)
            let nextLocation = CLLocationCoordinate2D(latitude: wayPointArray[1].latitude ?? 0, longitude: wayPointArray[1].longitude ?? 0)
            
            //startDirection 계산
            var firstIndexCLLocation = CLLocation(latitude: wayPointArray[0].latitude ?? 0, longitude: wayPointArray[0].longitude ?? 0)
            var secondIndexCLLocation = CLLocation(latitude: wayPointArray[1].latitude ?? 0, longitude: wayPointArray[1].longitude ?? 0)
            
            self.startDirection = calculateDirection(from: firstIndexCLLocation, to: secondIndexCLLocation) - directionAdjustValue
        }
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
    
    // 네비에이션
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
            if currentWayPointIndex < wayPointArray.count {
                let currentWayPoint = wayPointArray[currentWayPointIndex]
                let wayPointLocation = CLLocation(latitude: currentWayPoint.latitude ?? 0, longitude: currentWayPoint.longitude ?? 0)
                
                print("현재와 다음 경유지 : ", wayPointArray[currentWayPointIndex].name, wayPointArray[currentWayPointIndex + 1].name)
                if userLocation.distance(from: wayPointLocation) <= 10 {
                    // 1m 이내로 접근한 경우
                    let instruction = formatInstruction(description: currentWayPoint.description ?? "", turnType: currentWayPoint.turnType ?? 0)
                    let direction = directionDescription(from: currentWayPoint.turnType ?? 0)
                    let facility = facilityDescription(from: currentWayPoint.facilityType)
                    let time = currentWayPoint.time ?? ""
                    
                    resultString = "\(instruction) \(facility) \(direction) \(time)입니다."
                    print("실시간 네비게이션 :", resultString)
                    
                    // 다음 경유지로 인덱스 업데이트
                    currentWayPointIndex += 1
                    updateNavigationInfo(for: userLocation)
                }
            }
            
        }
        print("경유지 배열!", self.wayPointArray)
    }
    
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
            turnType: pointTurnType,
            facilityType: pointFacilityType.description,
            roadType: lineStringRoadType,
            time: lineStringTime.description
        )
    }
    
    //실시간 네비게이션 서비스
    func startRealTimeNavigation() {
        
    }
    
    func stopRealTimeNavigation() {
        
    }
}

//실시간 네비게이션 관련 기능
extension MapViewModel {
    
    func updateNavigationInfo(for location: CLLocation) {
        guard currentWayPointIndex < wayPointArray.count else { return }
        
        let currentWayPoint = wayPointArray[currentWayPointIndex]
        let wayPointLocation = CLLocation(latitude: currentWayPoint.latitude ?? 0, longitude: currentWayPoint.longitude ?? 0)
        
        if location.distance(from: wayPointLocation) <= 1 {  // 1m 이내로 접근 시
            let instruction = formatInstruction(description: currentWayPoint.description ?? "", turnType: currentWayPoint.turnType ?? 0)
            let facility = facilityDescription(from: currentWayPoint.facilityType)
            let direction = directionDescription(from: currentWayPoint.turnType ?? 0)
            let roadType = roadTypeDescription(from: currentWayPoint.roadType)
            let time = currentWayPoint.time ?? ""
            
            resultString = "\(instruction) \(facility) \(direction) \(roadType) \(time)입니다."
            print("resultString in updateNavigationInfo", resultString)
            
            currentWayPointIndex += 1  // 다음 경유지로 인덱스 업데이트
        }
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
    
    func calculateDirection(from startLocation: CLLocation, to endLocation: CLLocation) -> CLLocationDirection {
        let lat1 = startLocation.coordinate.latitude.toRadians()
        let lon1 = startLocation.coordinate.longitude.toRadians()

        let lat2 = endLocation.coordinate.latitude.toRadians()
        let lon2 = endLocation.coordinate.longitude.toRadians()

        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)

        let degreesBearing = radiansBearing.toDegrees()
        
        return (degreesBearing + 360).truncatingRemainder(dividingBy: 360) // 0도에서 360도 사이의 값으로 정규화
    }
}

extension CLLocationDegrees {
    func toRadians() -> Double {
        return self * .pi / 180.0
    }

    func toDegrees() -> Double {
        return self * 180.0 / .pi
    }
}
