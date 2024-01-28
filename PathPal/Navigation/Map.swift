//
//  MapView.swift
//  PathPal
//
//  Created by Suji Lee on 12/26/23.
//

import SwiftUI
import GoogleMaps

struct MapView: View {
    
    @ObservedObject var mapVM: MapViewModel
    @State var showingPopup: Bool = false
    
    var body: some View {
        VStack {
            GoogleMapsView(mapVM: mapVM)
        }
    }
}

struct GoogleMapsView: UIViewRepresentable {
    @ObservedObject var mapVM: MapViewModel
    @State private var didLoadInitialPosition = false
    
    func makeUIView(context: Context) -> GMSMapView {
        let mapView = GMSMapView(frame: CGRect.zero)
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
        
        // 초기 카메라 위치를 사용자의 현재 위치로 설정
        if !didLoadInitialPosition {
            let camera = GMSCameraPosition.camera(withLatitude: mapVM.userLocation.coordinate.latitude,
                                                  longitude: mapVM.userLocation.coordinate.longitude,
                                                  zoom: 15)
            mapView.camera = camera
            didLoadInitialPosition = true
        }
        
        return mapView
    }
    
    func updateUIView(_ uiView: GMSMapView, context: Context) {
        
        // 경로를 선으로 연결
        let path = GMSMutablePath()
        mapVM.coordinatesForMap.forEach { coordinate in
            path.add(coordinate)
        }
        
        let polyline = GMSPolyline(path: path)
        polyline.strokeWidth = 5.0
        polyline.strokeColor = UIColor.hex246FFF
        polyline.map = uiView
        
        // 출발지 마커 추가
        if let startLat = Double(mapVM.startingPoint.noorLat ?? ""), let startLon = Double(mapVM.startingPoint.noorLon ?? "") {
            let startCoordinate = CLLocationCoordinate2D(latitude: startLat, longitude: startLon)
            let startMarker = GMSMarker(position: startCoordinate)
            startMarker.title = "출발지"
            startMarker.map = uiView
        }
        
        // 도착지 마커 추가
        if let endLat = Double(mapVM.destination.noorLat ?? ""), let endLon = Double(mapVM.destination.noorLon ?? "") {
            let endCoordinate = CLLocationCoordinate2D(latitude: endLat, longitude: endLon)
            let endMarker = GMSMarker(position: endCoordinate)
            endMarker.title = "도착지"
            endMarker.map = uiView
        }
    }
}
