//
//  MapView.swift
//  PathPal
//
//  Created by Suji Lee on 12/26/23.
//

import SwiftUI
import GoogleMaps
import CoreLocation
import Combine

struct GoogleMapsView: UIViewRepresentable {

    @ObservedObject var locationManager: LocationManager
    
    var cancellables = Set<AnyCancellable>()

    
    func makeUIView(context: Context) -> GMSMapView {
        let mapView = GMSMapView(frame: CGRect.zero)
        mapView.isMyLocationEnabled = true
        locationManager.mapView = mapView // Store reference to mapView
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // This will now continuously update as locationManager publishes changes.
        if let location = locationManager.lastLocation {
            let camera = GMSCameraPosition.camera(withLatitude: location.coordinate.latitude,
                                                  longitude: location.coordinate.longitude,
                                                  zoom: 15,
                                                  bearing: locationManager.bearing,
                                                  viewingAngle: mapView.camera.viewingAngle) // Adjust as needed
            mapView.animate(to: camera)
        }
        
        // 시작점과 끝점 가정
        let start = locationManager.lastLocation
//        let destinationCoordinate = CLLocationCoordinate2D(latitude: DEST_LAT, longitude: DEST_LNG)

        // 경로 계산 및 표시
//        DirectionsService().getDirections(from: locationManager.lastLocation.coordinate, to: destinationCoordinate)
//            .sink(receiveCompletion: { completion in
//                if case let .failure(error) = completion {
//                    print(error.localizedDescription)
//                }
//            }, receiveValue: { path in
//                let route = GMSPolyline(path: path)
//                route.strokeColor = .blue
//                route.strokeWidth = 4.0
//                route.map = self.locationManager.mapView
//                
//                // 경로 정보 추출 및 표시
//                // 예: 거리, 예상 소요 시간
//                // 이 정보는 Directions API의 응답에 포함되어 있음
//            })
//            .store(in: &cancellables)
        
    }
    
    typealias UIViewType = GMSMapView
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CLLocationManagerDelegate {
        var parent: GoogleMapsView
        
        init(_ parent: GoogleMapsView) {
            self.parent = parent
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var lastLocation: CLLocation?
    @Published var isLoading = true  // Tracks if the location is being loaded initially
    var bearing: CLLocationDirection = 0 // Holds the latest heading/bearing
    var mapView: GMSMapView?
    
    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.startUpdatingLocation()
        self.locationManager.startUpdatingHeading()  // Start receiving heading updates
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            lastLocation = location
            isLoading = false
//          print("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        bearing = newHeading.trueHeading != -1 ? newHeading.trueHeading : newHeading.magneticHeading
//      print("Heading updated: \(bearing)")
    }

}

struct Map: View {
    @StateObject var locationManager = LocationManager()
    
    var body: some View {
        ZStack {
            if locationManager.isLoading {
                ProgressView()
            } else {
                GoogleMapsView(locationManager: locationManager)
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }
}

class DirectionsService {
    func getDirections(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> AnyPublisher<GMSPath, Error> {
        let urlString = "https://maps.googleapis.com/maps/api/directions/json?origin=\(start.latitude),\(start.longitude)&destination=\(end.latitude),\(end.longitude)&key=YOUR_API_KEY"
        
        return URLSession.shared.dataTaskPublisher(for: URL(string: urlString)!)
            .map { $0.data }
            .decode(type: DirectionsResponse.self, decoder: JSONDecoder())
            .tryMap { response in
                guard let points = response.routes.first?.overviewPolyline.points else {
                    throw URLError(.badServerResponse)
                }
                return GMSPath(fromEncodedPath: points)!
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

struct DirectionsResponse: Codable {
    var routes: [Route]
}

struct Route: Codable {
    var overviewPolyline: OverViewPolyline
}

struct OverViewPolyline: Codable {
    var points: String
}

class Coordinator: NSObject {
    var cancellables: Set<AnyCancellable> = []
    // 나머지 Coordinator 구현...
}
