//
//  MapView.swift
//  PathPal
//
//  Created by Suji Lee on 12/26/23.
//

import SwiftUI
import GoogleMaps
import CoreLocation

struct GoogleMapsView: UIViewRepresentable {
    @ObservedObject var locationManager: LocationManager
    
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
            isLoading = false  // Got the location, no longer loading
//            print("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        bearing = newHeading.trueHeading != -1 ? newHeading.trueHeading : newHeading.magneticHeading
//        print("Heading updated: \(bearing)")
    }
    
    // Include other delegate methods and error handling as necessary
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
