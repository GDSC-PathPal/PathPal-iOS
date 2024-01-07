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
import GooglePlaces

var userLocation: CLLocation = CLLocation(latitude: 2.111111, longitude: 2.111111)
var userHeading: CLLocationDirection = CLLocationDirection()

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
            userLocation = location
            isLoading = false
            //          print("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        bearing = newHeading.trueHeading != -1 ? newHeading.trueHeading : newHeading.magneticHeading
        userHeading = newHeading.trueHeading != -1 ? newHeading.trueHeading : newHeading.magneticHeading
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
                VStack {
                    SearchView()
                }
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



















//let GOOGLE_PLACES_API_KEY = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_PLACES_API_KEY") as? String
//
//var userLocation: CLLocation = CLLocation(latitude: 0.11, longitude: 0.11)
//var userHeading: CLLocationDirection = CLLocationDirection()
//
//struct PlacePrediction: Codable {
//    let placeId: String
//    let description: String
//    let structuredFormatting: StructuredFormatting
//
//    enum CodingKeys: String, CodingKey {
//        case placeId = "place_id"
//        case description
//        case structuredFormatting = "structured_formatting"
//    }
//}
//
//struct StructuredFormatting: Codable {
//    let mainText: String
//    let secondaryText: String
//
//    enum CodingKeys: String, CodingKey {
//        case mainText = "main_text"
//        case secondaryText = "secondary_text"
//    }
//}
//
//struct PlaceDetail: Codable {
//    let placeId: String
//    let name: String
//    let geometry: Geometry
//
//    enum CodingKeys: String, CodingKey {
//        case placeId = "place_id"
//        case name
//        case geometry
//    }
//}
//
//struct Geometry: Codable {
//    let location: Location
//}
//
//struct Location: Codable {
//    let lat: Double
//    let lng: Double
//}
//
//
//struct SearchPage: View {
//    @ObservedObject var locationManager: LocationManager
//    @State private var query: String = ""
//    @State private var places: [PlaceDetail] = []  // Changed to [PlaceDetail]
//    @State private var targetPlace: PlaceDetail?  // Changed from GMSPlace? to PlaceDetail?
//
//    var body: some View {
//        VStack {
//            TextField("Search places", text: $query)
//                .padding()
//            Button("Search") {
//                searchNearbyPlaces(query: query)
//            }
//            List(places, id: \.placeId) { place in
//                Text(place.name)
//                    .onTapGesture {
//                        self.targetPlace = place  // Assign the selected place to targetPlace
//                    }
//            }
//        }
//    }
//
//    func searchNearbyPlaces(query: String) {
//        let filter = GMSAutocompleteFilter()
//        filter.type = .establishment // Adjust the filter type based on your requirements
//
//        GMSPlacesClient.shared().findAutocompletePredictions(fromQuery: query,
//                                                             filter: filter,
//                                                             sessionToken: nil) { (results, error) in
//            if let error = error {
//                print("Error with autocomplete: \(error.localizedDescription)")
//                return
//            }
//            guard let predictions = results else {
//                print("No results found")
//                return
//            }
//
//            let group = DispatchGroup()
//            var fetchedPlaces: [PlaceDetail] = []
//
//            for prediction in predictions {
//                group.enter()
//                GMSPlacesClient.shared().fetchPlace(fromPlaceID: prediction.placeID,
//                                                    placeFields: .all,
//                                                    sessionToken: nil) { (place, error) in
//                    if let error = error {
//                        print("Error fetching place details: \(error.localizedDescription)")
//                        group.leave()
//                        return
//                    }
//                    if let place = place {
//                        let placeDetail = PlaceDetail(placeId: place.placeID ?? "",
//                                                      name: place.name ?? "",
//                                                      geometry: Geometry(location: Location(lat: place.coordinate.latitude, lng: place.coordinate.longitude)))
//                        fetchedPlaces.append(placeDetail)
//                        print("유저 장소 : ", userLocation)
//                    }
//                    group.leave()
//                }
//            }
//
//            group.notify(queue: .main) {
//                // Filter places to include only those within 1 km of the user's current location
//                let nearbyPlaces = fetchedPlaces.filter { placeDetail in
//                    // Calculate the distance between the user's location and the place's location
//                    let placeLocation = CLLocation(latitude: placeDetail.geometry.location.lat, longitude: placeDetail.geometry.location.lng)
//                    let distance = userLocation.distance(from: placeLocation)  // Default to 0 if lastLocation is nil
//
//                    return distance <= 30000000  // Keep only places within 1 km
//                }
//
//                self.places = nearbyPlaces  // Assigning filtered PlaceDetail objects to places
//                print("저장된 장소들 : ", places)
//            }
//        }
//    }
//
//}
//
//struct GoogleMapsView: UIViewRepresentable {
//
//    @ObservedObject var locationManager: LocationManager
//
//    var cancellables = Set<AnyCancellable>()
//
//    func makeUIView(context: Context) -> GMSMapView {
//        let mapView = GMSMapView(frame: CGRect.zero)
//        mapView.isMyLocationEnabled = true
//        locationManager.mapView = mapView // Store reference to mapView
//        return mapView
//    }
//
//    func updateUIView(_ mapView: GMSMapView, context: Context) {
//        // This will now continuously update as locationManager publishes changes.
//        if let location = locationManager.lastLocation {
//            let camera = GMSCameraPosition.camera(withLatitude: location.coordinate.latitude,
//                                                  longitude: location.coordinate.longitude,
//                                                  zoom: 15,
//                                                  bearing: locationManager.bearing,
//                                                  viewingAngle: mapView.camera.viewingAngle) // Adjust as needed
//            mapView.animate(to: camera)
//        }
//
//        // 시작점과 끝점 가정
//        let start = locationManager.lastLocation
//    }
//
//    typealias UIViewType = GMSMapView
//
//    func makeCoordinator() -> Coordinator {
//        Coordinator(self)
//    }
//
//    class Coordinator: NSObject, CLLocationManagerDelegate {
//        var parent: GoogleMapsView
//
//        init(_ parent: GoogleMapsView) {
//            self.parent = parent
//        }
//    }
//}
//
//class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
//    private let locationManager = CLLocationManager()
//    @Published var lastLocation: CLLocation?
//    @Published var isLoading = true  // Tracks if the location is being loaded initially
//    var bearing: CLLocationDirection = 0 // Holds the latest heading/bearing
//    var mapView: GMSMapView?
//
//    override init() {
//        super.init()
//        self.locationManager.delegate = self
//        self.locationManager.requestWhenInUseAuthorization()
//        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
//        self.locationManager.startUpdatingLocation()
//        self.locationManager.startUpdatingHeading()  // Start receiving heading updates
//    }
//
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        if let location = locations.last {
//            lastLocation = location
//            userLocation = location
//            isLoading = false
////          print("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
//            print("Location updated: \(userLocation.coordinate.latitude), \(userLocation.coordinate.longitude)")
//
//        }
//    }
//
//    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
//        bearing = newHeading.trueHeading != -1 ? newHeading.trueHeading : newHeading.magneticHeading
//        userHeading = newHeading.trueHeading != -1 ? newHeading.trueHeading : newHeading.magneticHeading
////      print("Heading updated: \(bearing)")
//    }
//
//}
//
//// Make sure to inject locationManager instance to SearchPage in your Map View
//struct Map: View {
//    @StateObject var locationManager = LocationManager()
//
//    var body: some View {
//        ZStack {
//            if locationManager.isLoading {
//                ProgressView()
//            } else {
//                GoogleMapsView(locationManager: locationManager)
//                    .edgesIgnoringSafeArea(.all)
//                SearchPage(locationManager: locationManager)
//            }
//        }
//    }
//}
//
//class DirectionsService {
//    func getDirections(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> AnyPublisher<GMSPath, Error> {
//
//            let urlString = "https://maps.googleapis.com/maps/api/directions/json?origin=\(start.latitude),\(start.longitude)&destination=\(end.latitude),\(end.longitude)&key=\(GOOGLE_PLACES_API_KEY)Y"
//
//            return URLSession.shared.dataTaskPublisher(for: URL(string: urlString)!)
//                .map { $0.data }
//                .decode(type: DirectionsResponse.self, decoder: JSONDecoder())
//                .tryMap { response in
//                    guard let points = response.routes.first?.overviewPolyline.points else {
//                        throw URLError(.badServerResponse)
//                    }
//                    return GMSPath(fromEncodedPath: points)!
//                }
//                .receive(on: DispatchQueue.main)
//                .eraseToAnyPublisher()
//        }
//
//}
//
//struct DirectionsResponse: Codable {
//    var routes: [Route]
//}
//
//struct Route: Codable {
//    var overviewPolyline: OverViewPolyline
//}
//
//struct OverViewPolyline: Codable {
//    var points: String
//}
//
//class Coordinator: NSObject {
//    var cancellables: Set<AnyCancellable> = []
//    // 나머지 Coordinator 구현...
//}
