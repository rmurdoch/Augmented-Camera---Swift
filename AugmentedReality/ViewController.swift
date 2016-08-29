//
//  ViewController.swift
//  AugmentedReality
//
//  Created by Andrew Murdoch on 8/27/16.
//  Copyright © 2016 Andrew Murdoch. All rights reserved.
//

import UIKit
import CoreLocation
import CoreMotion

class ViewController: UIViewController {
    
    @IBOutlet weak var overlayView: UIView!
    
    var timer: Timer?
    
    var centerCoordinate: Coordinate?
    
    var coordinates = [Coordinate]()
    var coordinateViews = [UIView]()
    
    var currentLocation: CLLocation?
    var locationManager: CLLocationManager?
    var motionManager: CMMotionManager?
    
    var maxScaleDistance = 0.0
    
    var rollingX = Double(0)
    var rollingZ = Double(0)
    
    private var _cameraController: UIImagePickerController?
    
    var cameraController: UIImagePickerController {
        if _cameraController == nil {
            _cameraController = UIImagePickerController()
            _cameraController?.sourceType = .camera
            _cameraController?.showsCameraControls = false
            _cameraController?.isNavigationBarHidden = true
            _cameraController?.modalPresentationStyle = .fullScreen
        }
        return _cameraController!
    }
}


//MARK: MapViewController Delegate
extension ViewController: MapViewControllerDelegate {
    
    @IBAction func mapPressed(_ sender: AnyObject) {
        let mapVC = storyboard?.instantiateViewController(withIdentifier: "MapViewController") as! MapViewController
        mapVC.delegate = self
        self.present(mapVC, animated: true, completion: nil)
    }
    
    func mapViewControllerDidFinish(with coordinates: [Coordinate], vc: MapViewController) {
        coordinates.forEach{ self.add($0) }
        
        self.beginMonitoring()

        vc.dismiss(animated: true) {
            self.present(self.cameraController, animated: true) {
                self.overlayView.frame = self.cameraController.view.bounds
                self.cameraController.cameraOverlayView = self.overlayView
            }
        }
    }
    
    func add(_ coordinate: Coordinate) {
        
        coordinates.append(coordinate)
        
        if coordinate.radiusDistance > self.maxScaleDistance {
            self.maxScaleDistance = coordinate.radiusDistance
        }
        
        coordinateViews.append(self.view(from: coordinate))
    }
}


//MARK: Monitoring Location and Motion
extension ViewController {
    func beginMonitoring() {
        
        if centerCoordinate == nil {
            self.centerCoordinate = Coordinate.init(0, 0, 0)
        }
        
        if locationManager == nil {
            locationManager = CLLocationManager()
            locationManager?.requestWhenInUseAuthorization()
            locationManager?.headingFilter = kCLHeadingFilterNone
            locationManager?.desiredAccuracy = kCLLocationAccuracyBest
            locationManager?.delegate = self
        }
        
        if motionManager == nil {
            motionManager = CMMotionManager()
            motionManager?.accelerometerUpdateInterval = 0.01
            
            motionManager?.startAccelerometerUpdates(to: OperationQueue.main) {_,_ in
                self.updateAccelerometer()
            }
        }
        
        if self.timer == nil {
            self.timer = Timer(timeInterval: Constants.frequency, target: self, selector: #selector(ViewController.updateLocations), userInfo: nil, repeats: true)
            self.timer?.fire()
            RunLoop.current.add(self.timer!, forMode: RunLoopMode.commonModes)
        }
    }
    
    func endMonitoring() {
        locationManager?.stopUpdatingHeading()
        locationManager = nil
        
        motionManager?.stopAccelerometerUpdates()
        motionManager = nil
    }
}


//MARK: Updating Coordinate Views
extension ViewController {
    func updateLocations() {
        if coordinates.count > 0 {
            coordinates.forEach{ self.check($0) }
        }
    }
    
    func check(_ coordinate: Coordinate) {
        let view = coordinateViews[coordinates.index(of: coordinate)!]
        if coordinate.viewContains(self.centerCoordinate!) {
            self.update(coordinate, view)
        } else {
            view.removeFromSuperview()
            view.transform = CGAffineTransform.identity
        }
    }
    
    func update(_ coordinate: Coordinate,_ coordinateView: UIView) {
        
        let location = coordinate.point(in: overlayView, from: self.centerCoordinate!)
        var scale = CGFloat(1.0)
        let view = coordinateView
        
        if Constants.scaleByDistance {
            scale = CGFloat(1.0) * CGFloat(coordinate.radiusDistance / maxScaleDistance)
        }
        
        let width = view.bounds.width * scale
        let height = view.bounds.height * scale
        
        view.frame = CGRect(x: location.x - width / CGFloat(2.0), y: location.y - height / CGFloat(2.0), width: width, height: height)
        
        var transform = CATransform3DIdentity
        
        if Constants.scaleByDistance {
            transform = CATransform3DScale(transform, scale, scale, scale)
        }
        
        if Constants.allowRotate {
            transform.m34 = 1 / 300
            
            if var centerAzimuth = self.centerCoordinate?.azimuth {
                if coordinate.azimuth - centerAzimuth > M_PI {
                    centerAzimuth += 2 * M_PI
                }
                if coordinate.azimuth - centerAzimuth < -M_PI {
                    coordinate.azimuth += 2 * M_PI
                }
                
                let angleDifference = coordinate.azimuth - centerAzimuth
                transform = CATransform3DRotate(transform, CGFloat(Constants.maxRotationAngle * angleDifference / (Constants.radianHeight / 2.0)) , 0, 1, 0)
            }
        }
        
        if view.superview == nil {
            overlayView.addSubview(view)
            overlayView.sendSubview(toBack: view)
        }
    }
}



//MARK: Location Delegate
extension ViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            manager.startUpdatingHeading()
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        self.centerCoordinate?.azimuth = fmod(newHeading.magneticHeading, 360.0) * (2 * (M_PI / 360.0))
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if locations.count > 0 {
            centerLocation = locations[0]
        }
    }
    
    
    var centerLocation: CLLocation {
        get {
            return currentLocation!
        }
        set {
            currentLocation = newValue
            self.coordinates.forEach{ self.checkCalibration($0) }
        }
    }
    
    func checkCalibration(_ coordinate: Coordinate) {
        
        coordinate.calibrate(centerLocation)
        
        if coordinate.radiusDistance > self.maxScaleDistance {
            self.maxScaleDistance = coordinate.radiusDistance
        }
    }
}


//MARK: Accelerometer Updates
extension ViewController {
    
    func updateAccelerometer() {
        let acceleration = motionManager?.accelerometerData?.acceleration
        
        rollingZ  = ((acceleration?.z)! * Constants.filterFactor) + (rollingZ  * (1.0 - Constants.filterFactor))
        rollingX = ((acceleration?.y)! * Constants.filterFactor) + (rollingX * (1.0 - Constants.filterFactor))
        
        if rollingZ > 0.0 {
            self.centerCoordinate?.inclination = atan(rollingX / rollingZ) + M_PI / 2.0
        } else if rollingZ < 0.0 {
            self.centerCoordinate?.inclination = atan(rollingX / rollingZ) - M_PI / 2.0
        } else if rollingX < 0 {
            self.centerCoordinate?.inclination = M_PI/2.0
        } else if rollingX >= 0 {
            self.centerCoordinate?.inclination = 3 * M_PI/2.0
        }
    }
}


//MARK: Custom View for Coordinates on Overlay View
extension ViewController {
    func view(from coordinate: Coordinate) -> UIView {
        
        let width  = CGFloat(150)
        let height = CGFloat(100)
        
        let view = UIView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: width, height: 20))
        label.backgroundColor = UIColor.red
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.text = "\(coordinate.title)"
        
        view.addSubview(label)
        view.backgroundColor = UIColor.red.withAlphaComponent(0.4)
        
        return view
    }
}
