//
//  MapViewController.swift
//  AugmentedReality
//
//  Created by Andrew Murdoch on 8/29/16.
//  Copyright © 2016 Andrew Murdoch. All rights reserved.
//

import UIKit
import MapKit

protocol MapViewControllerDelegate {
    func mapViewControllerDidFinish(with coordinates: [Coordinate], vc: MapViewController)
}

class MapViewController: UIViewController {
    
    var delegate: MapViewControllerDelegate?
    static let Identifier = "Pin"

    @IBOutlet weak var mapView: MKMapView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func donePressed(_ sender: AnyObject) {
        let pins = self.mapView.annotations.map{ $0.coordinate }
        let coordinates = pins.flatMap{ Coordinate.init(CLLocation(latitude: $0.latitude, longitude: $0.longitude)) }
        self.delegate?.mapViewControllerDidFinish(with: coordinates, vc: self)
    }
    
    @IBAction func addAnnotation(gestureRecognizer:UIGestureRecognizer) {
        if gestureRecognizer.state == .began {
            let touchPoint = gestureRecognizer.location(in: mapView)
            let coordinates = mapView.convert(touchPoint, toCoordinateFrom: mapView)
            mapView.addAnnotation(Annotation(coordinate: coordinates))
        }
    }
}


extension MapViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        var region = MKCoordinateRegion()
        var span = MKCoordinateSpan()
        span.latitudeDelta = 0.005
        span.longitudeDelta = 0.005
        region.span = span
        
        var location = CLLocationCoordinate2D()
        location.latitude = userLocation.location!.coordinate.latitude
        location.longitude = userLocation.location!.coordinate.longitude
        region.center = location;
        
        mapView.setRegion(region, animated: true)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation.isKind(of: Annotation.classForCoder()) {
            var pin = mapView.dequeueReusableAnnotationView(withIdentifier: MapViewController.Identifier) as! AnnotationView?
            
            if pin == nil {
                pin = AnnotationView.init(annotation: annotation, reuseIdentifier: MapViewController.Identifier)
            }
            
            pin?.animatesDrop = true
            return pin
        }
        
        return nil
    }
}

class Annotation: NSObject, MKAnnotation {
    var coordinate = CLLocationCoordinate2D()
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

class AnnotationView: MKPinAnnotationView  {
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        self.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
