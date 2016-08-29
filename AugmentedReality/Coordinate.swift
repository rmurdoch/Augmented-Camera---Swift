//
//  Coordinate.swift
//  AugmentedReality
//
//  Created by Andrew Murdoch on 8/27/16.
//  Copyright © 2016 Andrew Murdoch. All rights reserved.
//

import UIKit
import CoreLocation

class Coordinate: NSObject {
    var title: NSString?
    var subtitle: String?
    
    var radiusDistance = Double(10)
    var inclination = Double(0)
    var azimuth = Double(0)
    
    var geoLocation: CLLocation?
    
    //MARK: Initializers
    convenience init(_ radiusDistance: Double,_ inclination: Double,_ azimuth: Double) {
        self.init()
        self.radiusDistance = radiusDistance
        self.inclination = inclination
        self.azimuth = azimuth
    }
    
    convenience init(_ location: CLLocation) {
        self.init()
        self.geoLocation = location
    }
}


extension Coordinate {
    
    //MARK: Get point in overlayview from coordinate
    func point(in view: UIView, from centerCoordinate: Coordinate) -> CGPoint {
        var point = CGPoint()
        
        let pointAzimuth = self.azimuth
        var leftAzimuth = (centerCoordinate.azimuth) - Constants.radianWidth / 2.0
        
        if leftAzimuth < 0.0 {
            leftAzimuth = 2 * M_PI + leftAzimuth
        }
        
        if pointAzimuth < leftAzimuth {
            let doublePi = CGFloat(2 * M_PI)
            let adjustedAzimuth = CGFloat(leftAzimuth + pointAzimuth)
            point.x = ((doublePi - adjustedAzimuth) / CGFloat(Constants.radianWidth)) * view.frame.width
        } else {
            point.x = CGFloat(((pointAzimuth - leftAzimuth) / Constants.radianWidth)) * view.frame.width
        }
        
        let pointInclination = self.inclination
        let topInclination = (centerCoordinate.inclination) - Constants.radianHeight / 2.0
        
        point.y = view.frame.height - CGFloat(((pointInclination - topInclination) / Constants.radianHeight)) * view.frame.height
        
        return point
    }
    
    
    //MARK: Check if the view contains the coordinate
    func viewContains(_ centerCoordinate: Coordinate) -> Bool {
        
        let centerAzimuth = centerCoordinate.azimuth
        var leftAzimuth = centerAzimuth - Constants.radianWidth / 2.0
        
        if leftAzimuth < 0.0 {
            leftAzimuth = 2 * M_PI + leftAzimuth
        }
        
        var rightAzimuth = centerAzimuth + (Constants.radianWidth / 2.0)
        
        if rightAzimuth > 2 * M_PI {
            rightAzimuth = rightAzimuth - 2 * M_PI
        }
        
        var result = (self.azimuth > leftAzimuth && self.azimuth < rightAzimuth)
        
        if leftAzimuth > rightAzimuth {
            result = (self.azimuth < rightAzimuth || self.azimuth > leftAzimuth)
        }
        
        let centerInclination = centerCoordinate.inclination
        let bottomInclination = centerInclination - Constants.radianHeight / 2.0
        let topInclination = centerInclination + Constants.radianHeight / 2.0
        
        result = result && (self.inclination > bottomInclination && self.inclination < topInclination)
        
        return result
    }
    
    
    
    //MARK: Adjusting the coordinate from the current location
    func calibrate(_ origin: CLLocation) {
        if geoLocation != nil {
            
            let distance = origin.distance(from: geoLocation!)
            
            self.radiusDistance = sqrt(pow(origin.altitude - (geoLocation?.altitude)!, 2) + pow(distance, 2))
            
            var angle = sin(abs(origin.altitude - (geoLocation?.altitude)!) / radiusDistance)
            
            if origin.altitude > (geoLocation?.altitude)! {
                angle = -angle
            }
            
            inclination = angle
            azimuth = self.angleFrom(origin.coordinate, (geoLocation?.coordinate)!)
        }
    }
    
    func angleFrom(_ coordinate: CLLocationCoordinate2D,_ toCoordinate: CLLocationCoordinate2D) -> Double {
        let longitudinalDifference = toCoordinate.longitude - coordinate.longitude
        let latitudinalDifference = toCoordinate.latitude - coordinate.latitude
        
        let possibleAzimuth = (M_PI * 0.5) - atan(latitudinalDifference / longitudinalDifference)
        
        if (longitudinalDifference > 0) {
            return possibleAzimuth
        }
        else if (longitudinalDifference < 0) {
            return possibleAzimuth + M_PI
        }
        else if (latitudinalDifference < 0) {
            return M_PI
        }
        
        return 0.0
    }
}

