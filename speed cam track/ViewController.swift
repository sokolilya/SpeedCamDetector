//
// MainScreenModel.swift
// cryptocheck
//
// Created by Ilya Sokolov on 26.04.2019.
// Copyright © 2019 Vonnlu LTD. All rights reserved.
//

import UIKit
import CoreLocation
import SwiftyJSON
import Solar
import SwiftOverpass

struct Camera {
    var latitude: Double
    var longitude: Double
    var limit: Int
    var direction: Double
    var tag: String
}

struct Location {
    var latitude: Double
    var longitude: Double
    var speed: Int
    var speedLimit: Int
    var distanceToCamera: Double
    var roadLimit: Int
    var course: Double
}

class ViewController: UIViewController {
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return self.style
    }
    
    var style: UIStatusBarStyle = .default
    
    var camera = Camera(latitude: 0, longitude: 0, limit: 0, direction: -1.0, tag: "")
    var cameras = [Camera]()
    var removedCameras = [Camera]()
    var roadLimit = 0
    var savedDistanceToCamera = [Double]()
    var savedRemovedDistanceToCamera = [Double]()
    
    let locationManager = CLLocationManager()
    
    let roadType = ["primary", "secondary", "motorway", "trunk", "tertiary", "unclassified", "residential", "motorway_link", "trunk_link", "primary_link", "secondary_link", "tertiary_link"]
    let tags = ["traffic_sign=maxspeed","highway=speed_camera", "enforcement=maxspeed"]
    //"traffic_sign=maxspeed"
    
    var currentLocation = Location(latitude: 0, longitude: 0, speed: 0, speedLimit: 0, distanceToCamera: 0, roadLimit: 0, course: 0)
    var currentDistanceToCamera: Double! = 0
    var currentCameraSpeedLimit: Int! = 0
    
    var parseRoad = 0
    var getSpeedCamera = 0
    var count = 0
    
    var allowUpdateLabels = false
    var isUpdating = false
    var firstStart = true
    var getSpeedCameraBool = true
    var getRoadBool = true
    var doubleTap = false
    var tappedDay: Bool?
    var sorted = false
    var saveCourse = true
    var saveDistance = true
    var saveDistanceCount = [Int]()
    var saveRemovedDistanceCount = [Int]()
    
    var lastDirection: Double! = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        currentSpeedLabel.isHidden = true
        currentSpeedLimitLabel.isHidden = true
        cameraBioLabel.isHidden = true
        cameraSpeedLimitLabel.isHidden = true
        
        activityIndicators[0].startAnimating()
        activityIndicators[1].startAnimating()
        activityIndicators[2].startAnimating()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 1
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = .automotiveNavigation
        locationManager.startUpdatingLocation()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped))
        tap.numberOfTapsRequired = 2
        view.addGestureRecognizer(tap)
    }
    
    @objc func doubleTapped() {
        if tappedDay != nil {
            doubleTap = true
            if tappedDay! {
                tappedDay = false
            } else if !tappedDay! {
                tappedDay = true
            }
            updateUI(location: CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude))
        }
    }
    
    @IBOutlet weak var currentSpeedLabel: UILabel!
    @IBOutlet weak var currentSpeedLimitLabel: UILabel!
    @IBOutlet weak var cameraBioLabel: UILabel!
    @IBOutlet weak var cameraSpeedLimitLabel: UILabel!
    @IBOutlet var activityIndicators: [UIActivityIndicatorView]!
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var middleView: UIView!
    @IBOutlet weak var bottomView: UIView!
    
    func getCameraXML(location: CLLocation) {
        getSpeedCameraBool = false
        let cameraQuery = NodeQuery()
        let enforcementQuery = NodeQuery()
        let signQuery = NodeQuery()
        let bbox = BoudingBox(s: location.coordinate.latitude - 0.05, n: location.coordinate.latitude + 0.05, w: location.coordinate.longitude - 0.05, e: location.coordinate.longitude + 0.05)
        cameraQuery.setBoudingBox(bbox)
        enforcementQuery.setBoudingBox(bbox)
        signQuery.setBoudingBox(bbox)
        cameraQuery.hasTag("highway", equals: "speed_camera")
        enforcementQuery.hasTag("enforcement", equals: "maxspeed")
        signQuery.hasTag("traffic_sign", equals: "maxspeed")
        
        SwiftOverpass.api(endpoint: "http://overpass.openstreetmap.ru/cgi/interpreter").fetch([cameraQuery, enforcementQuery]) { (response) in
            //print(response.xml)
            self.count = 0
            if response.nodes?.count ?? 0 > 0 {
                for node in response.nodes! {
                    self.camera.latitude = node.latitude
                    self.camera.longitude = node.longitude
                    for tag in node.tags {
                        if tag.key == "maxspeed" {
                            let strArr = tag.value.components(separatedBy: " ")
                            if strArr.count > 1 {
                                if strArr[1] == "kmh" || strArr[1] == "km/h" || strArr[1] == "kmph" {
                                    self.camera.limit = Int(Double(strArr[0]) ?? 0 * 0.62)
                                } else {
                                    self.camera.limit = Int(strArr[0]) ?? 0
                                }
                            } else {
                                self.camera.limit = Int(strArr[0]) ?? 0
                            }
                        }
                        if tag.key == "direction" {
                            self.camera.direction = Double(tag.value) ?? -1.0
                        }
                        for someTag in self.tags {
                            let fullTag = tag.key + "=" + tag.value
                            if fullTag == someTag {
                                self.camera.tag = someTag
                            }
                        }
                    }
                    self.cameras.append(self.camera)
                    self.count += 1
                    self.saveDistanceCount.append(0)
                    self.savedDistanceToCamera.append(location.distance(from: CLLocation(latitude: self.camera.latitude, longitude: self.camera.longitude)))
                }
            }
        }
        allowUpdateLabels = true
        saveDistance = true
        if cameras.count > 1 && count > 0 {
            sorted = false
            lowerToBigger(location: CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude))
        }
        getSpeedCameraBool = true
    }
    
//    func getCamera(location: CLLocation) {
//        getSpeedCameraBool = false
//        for tag in tags {
//            let url = URL(string: "http://overpass.openstreetmap.ru/cgi/interpreter?data=[out:json];node[\(tag)](\(location.coordinate.latitude - 0.05),\(location.coordinate.longitude - 0.05),\(location.coordinate.latitude + 0.05),\(location.coordinate.longitude + 0.05));out%20meta;")!
//
//            let dataTask = URLSession.shared.dataTask(with: url) { data, response, error in
//                guard
//                    error == nil,
//                    let data = data
//                    else {
//                        print("Network Error SpeedCamera")
//                        return
//                }
//                let json = JSON(data)
//                self.count = 0
//                if let nodes = json["elements"].array {
//                    for node in nodes {
//                        if let latitude = node["lat"].double {
//                            self.camera.latitude = latitude
//                        }
//                        if let longitude = node["lon"].double {
//                            self.camera.longitude = longitude
//                        }
//                        if let tags = node["tags"].dictionary {
//                            if tags["maxspeed"]?.stringValue == "RU:urban" {
//                                self.camera.limit = 60
//                            } else {
//                                self.camera.limit = tags["maxspeed"]?.intValue ?? 0
//                            }
//                            if let direction = tags["direction"]?.intValue {
//                                self.camera.direction = Double(direction)
//                                //print(self.camera.direction)
//                            } else {
//                                self.camera.direction = -1.0
//                                //print(self.camera.direction)
//                            }
//                        }
//                        self.camera.tag = tag
//                        self.cameras.append(self.camera)
//                        self.saveDistanceCount.append(0)
//                        self.savedDistanceToCamera.append(location.distance(from: CLLocation(latitude: self.camera.latitude, longitude: self.camera.longitude)))
//                        self.count += 1
//                        //print(location.distance(from: CLLocation(latitude: self.camera.latitude, longitude: self.camera.longitude)))
//                    }
//                }
//            }
//            dataTask.resume()
//        }
//        allowUpdateLabels = true
//        saveDistance = true
//        if cameras.count > 1 && count > 0 {
//            sorted = false
//            sortCameras(location: CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude))
//            lowerToBigger(location: CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude))
//        }
//        getSpeedCameraBool = true
//    }
    
    func getRoad(location: CLLocation) {
        getRoadBool = false
        for type in roadType {
            let url = URL(string: "http://overpass.openstreetmap.ru/cgi/interpreter?data=[out:json];way[highway=\(type)](\(location.coordinate.latitude - 0.0001),\(location.coordinate.longitude - 0.0001),\(location.coordinate.latitude + 0.0001),\(location.coordinate.longitude + 0.0001));out%20meta;")!
            
            let dataTask = URLSession.shared.dataTask(with: url) { data, response, error in
                guard
                    error == nil,
                    let data = data
                    else {
                        print("Network Error Road")
                        return
                    }
                let json = JSON(data)
                if let ways = json["elements"].array {
                    for way in ways {
                        if let tags = way["tags"].dictionary {
                            var maxSpeed = 0
                            if tags["maxspeed"]?.intValue ?? 0 > maxSpeed {
                                maxSpeed = tags["maxspeed"]!.intValue
                            }
                            self.roadLimit = maxSpeed
                        }
                    }
                }
            }
            currentLocation.roadLimit = roadLimit
            dataTask.resume()
        }
        getRoadBool = true
    }
    
    func updateLabels() {
        if allowUpdateLabels {
            if firstStart && isUpdating {
                currentSpeedLimitLabel.isHidden = false
                currentSpeedLabel.isHidden = false
                cameraSpeedLimitLabel.isHidden = false
                cameraBioLabel.isHidden = false
                
                activityIndicators[0].stopAnimating()
                activityIndicators[1].stopAnimating()
                activityIndicators[2].stopAnimating()
                
                activityIndicators[0].isHidden = true
                activityIndicators[1].isHidden = true
                activityIndicators[2].isHidden = true
                
                firstStart = false
            }
            
            if isUpdating {
                if currentLocation.speedLimit != 0 {
                    cameraSpeedLimitLabel.text = "Speed limit: " + String(Int(currentLocation.speedLimit))
                } else {
                    self.cameraSpeedLimitLabel.text = "Unknown limit"
                }
                if cameras.count > 0 {
                    cameraBioLabel.text = String(Int(currentLocation.distanceToCamera)) + " m"
                    cameraSpeedLimitLabel.isHidden = false
                } else {
                    cameraBioLabel.text = "No cameras"
                    cameraSpeedLimitLabel.isHidden = true
                }
                if currentLocation.speed > 0 {
                    currentSpeedLabel.text = "Speed: " + String(currentLocation.speed) + " mph"
                } else {
                    currentSpeedLabel.text = "Speed: 0 mph"
                }
                if currentLocation.roadLimit > 0 {
                    currentSpeedLimitLabel.text = "Road limit: " + String(currentLocation.roadLimit)
                } else {
                    currentSpeedLimitLabel.text = "Unknown road limit"
                }
            }
        }
    }
    
    func sortCameras(location: CLLocation) {
        print("sort")
        if sorted {
            if cameras.count > 1 {
                var index = 0
                for camera in cameras {
                    if index < cameras.count {
                        for i in index..<cameras.count {
                            if (i != index) && (camera.latitude == cameras[i].latitude) && (camera.longitude == cameras[i].longitude) {
                                cameras.remove(at: i)
                                saveDistanceCount.remove(at: i)
                                savedDistanceToCamera.remove(at: i)
                                //print("Removed camera at index")
                                sortCameras(location: location)
                                return
                            }
                        }
                    }
                    index += 1
                }
            }
            
            if removedCameras.count > 1 {
                var removedIndex = 0
                for camera in removedCameras {
                    if removedIndex < removedCameras.count {
                        for i in removedIndex..<removedCameras.count {
                            if (i != removedIndex) && (camera.latitude == removedCameras[i].latitude) && (camera.longitude == removedCameras[i].longitude) {
                                removedCameras.remove(at: i)
                                saveRemovedDistanceCount.remove(at: i)
                                savedDistanceToCamera.remove(at: i)
                                //print("Removed camera at removedIndex")
                                sortCameras(location: location)
                                return
                            }
                        }
                    }
                    removedIndex += 1
                }
            }
        }
    }
    
    func lowerToBigger(location: CLLocation) {
        if cameras.count > 1 {
            for j in 0..<cameras.count {
                var k = j
                var buf: Camera?
                var bufCount: Int?
                var bufDistance: Double?
                for i in j+1..<cameras.count {
                    if location.distance(from: CLLocation(latitude: cameras[i].latitude, longitude: cameras[i].longitude)) < location.distance(from: CLLocation(latitude: cameras[k].latitude, longitude: cameras[k].longitude)) {
                        k = i
                    }
                }
                buf = cameras[j]
                bufCount = saveDistanceCount[j]
                bufDistance = savedDistanceToCamera[j]
                cameras[j] = cameras[k]
                saveDistanceCount[j] = saveDistanceCount[k]
                savedDistanceToCamera[j] = savedDistanceToCamera[k]
                cameras[k] = buf!
                saveDistanceCount[k] = bufCount!
                savedDistanceToCamera[k] = bufDistance!
            }
            checkDistanceToCamera()
        }
        sorted = true
        sortCameras(location: CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude))
    }
    
    func checkCourse(course: CLLocationDirection) {
        let changes = abs(course - lastDirection)
        if changes > 30.0 {
            //print("addedByCourse")
            cameras.append(contentsOf: removedCameras)
            saveDistanceCount.append(contentsOf: saveRemovedDistanceCount)
            savedDistanceToCamera.append(contentsOf: savedRemovedDistanceToCamera)
            removedCameras.removeAll()
            saveRemovedDistanceCount.removeAll()
            savedRemovedDistanceToCamera.removeAll()
            sorted = false
            saveCourse = true
            isUpdating = false
        }
    }
    
    func sortByCourse() {
        var index = 0
        for camera in cameras {
            if !(abs(currentLocation.course - camera.direction) < 135.0 && abs(currentLocation.course - camera.direction) > 90) && (camera.direction >= 0) {
                print("Sorting By Course")
                let removedCamera = cameras.remove(at: index)
                let removedCount = saveDistanceCount.remove(at: index)
                let removedDistance = savedDistanceToCamera.remove(at: index)
                removedCameras.append(removedCamera)
                saveRemovedDistanceCount.append(removedCount)
                savedRemovedDistanceToCamera.append(removedDistance)
                sortByCourse()
                return
            }
            index += 1
        }
    }
    
    func removeSame() {
        if removedCameras.count > 0 && cameras.count > 0 {
            for removedCamera in removedCameras {
                var check = 0
                for camera in cameras {
                    if removedCamera.latitude == camera.latitude && removedCamera.latitude == camera.latitude {
                        cameras.remove(at: check)
                        saveDistanceCount.remove(at: check)
                        savedDistanceToCamera.remove(at: check)
                        removeSame()
                        return
                    }
                    check += 1
                }
            }
        }
    }
    
    func checkDistanceToCamera() {
        if sorted && cameras.count > 0 && !saveDistance {
            //print(savedDistanceToCamera)
            print(currentLocation)
            for index in 0..<cameras.count {
                let changes = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude).distance(from: CLLocation(latitude: cameras[index].latitude, longitude: cameras[index].longitude)) - (savedDistanceToCamera[index])
                let distance = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude).distance(from: CLLocation(latitude: cameras[index].latitude, longitude: cameras[index].longitude))
                print("Distance(check): ", distance)
                print("Changes(check): ", changes)
                print(cameras[index])
                
                if distance <= 3.0 {
                    let removedCamera = cameras.remove(at: index)
                    let removedCount = saveDistanceCount.remove(at: index)
                    let removedDistance = savedDistanceToCamera.remove(at: index)
                    removedCameras.append(removedCamera)
                    saveRemovedDistanceCount.append(removedCount)
                    savedRemovedDistanceToCamera.append(removedDistance)
                    //print("removedByConnect")
                    checkDistanceToCamera()
                    return
                }
                
                if changes > 2.0 {
                    print("change")
                    saveDistanceCount[index] += 1
                    if saveDistanceCount[index] == 5 {
                        //print("removedByChanges")
                        saveDistanceCount[index] = 0
                        savedDistanceToCamera[index] = distance
                        let removedCamera = cameras.remove(at: index)
                        let removedCount = saveDistanceCount.remove(at: index)
                        let removedDistance = savedDistanceToCamera.remove(at: index)
                        removedCameras.append(removedCamera)
                        saveRemovedDistanceCount.append(removedCount)
                        savedRemovedDistanceToCamera.append(removedDistance)
                        checkDistanceToCamera()
                        isUpdating = true
                        return
                    }
                } else if changes < 0 && saveDistanceCount[index] > 0 {
                    saveDistanceCount[index] -= 1
                } else if saveDistanceCount[index] == 0 {
                    savedDistanceToCamera[index] = distance
                }
                
                if distance > 10000.0 {
                    cameras.remove(at: index)
                    saveDistanceCount.remove(at: index)
                    savedDistanceToCamera.remove(at: index)
                    //print("removedByDistance")
                    checkDistanceToCamera()
                    return
                }
            }
        } else {
            isUpdating = true
        }
    }
    
    func updateUI(location: CLLocation) {
        if doubleTap {
            if tappedDay! {
                topView.backgroundColor = UIColor.lightGray
                middleView.backgroundColor = UIColor.white
                bottomView.backgroundColor = UIColor.lightGray
                
                currentSpeedLabel.textColor = UIColor.black
                currentSpeedLimitLabel.textColor = UIColor.black
                cameraBioLabel.textColor = UIColor.black
                cameraSpeedLimitLabel.textColor = UIColor.black
                
                activityIndicators[0].style = .gray
                activityIndicators[1].style = .gray
                activityIndicators[2].style = .gray
                
                style = .default
            } else if !tappedDay! {
                topView.backgroundColor = UIColor.black
                middleView.backgroundColor = UIColor.black
                bottomView.backgroundColor = UIColor.black
                
                currentSpeedLabel.textColor = UIColor.lightGray
                currentSpeedLimitLabel.textColor = UIColor.lightGray
                cameraBioLabel.textColor = UIColor.lightGray
                cameraSpeedLimitLabel.textColor = UIColor.lightGray
                
                activityIndicators[0].style = .white
                activityIndicators[1].style = .white
                activityIndicators[2].style = .white
                
                style = .lightContent
            }
        } else if !doubleTap {
            let solar = Solar(coordinate: CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
            guard let isDaytime = solar?.isDaytime else { return }
            guard let isNighttime = solar?.isNighttime else { return }
            
            if isNighttime {
                topView.backgroundColor = UIColor.black
                middleView.backgroundColor = UIColor.black
                bottomView.backgroundColor = UIColor.black
                
                currentSpeedLabel.textColor = UIColor.lightGray
                currentSpeedLimitLabel.textColor = UIColor.lightGray
                cameraBioLabel.textColor = UIColor.lightGray
                cameraSpeedLimitLabel.textColor = UIColor.lightGray
                
                activityIndicators[0].style = .white
                activityIndicators[1].style = .white
                activityIndicators[2].style = .white
                
                style = .lightContent
                
                tappedDay = false
            } else if isDaytime {
                topView.backgroundColor = UIColor.lightGray
                middleView.backgroundColor = UIColor.white
                bottomView.backgroundColor = UIColor.lightGray
                
                currentSpeedLabel.textColor = UIColor.black
                currentSpeedLimitLabel.textColor = UIColor.black
                cameraBioLabel.textColor = UIColor.black
                cameraSpeedLimitLabel.textColor = UIColor.black
                
                activityIndicators[0].style = .gray
                activityIndicators[1].style = .gray
                activityIndicators[2].style = .gray
                
                style = .default
                
                tappedDay = true
            }
        }
    }

}

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            print("Not Determined")
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            print("Restricted or Denied")
        case .authorizedWhenInUse:
            print("Authorized When In Use")
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            print("Authorized Always")
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations[locations.count - 1]
        
        updateUI(location: location)
        removeSame()
        
        if location.horizontalAccuracy > 0 {
            
            if cameras.count > 0 && sorted {
                let distance = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude).distance(from: CLLocation(latitude: cameras[0].latitude, longitude: cameras[0].longitude))
                currentLocation.distanceToCamera = distance
                currentLocation.speedLimit = cameras[0].limit
            }
            
            checkDistanceToCamera()
            
            if location.course >= 0 && saveCourse {
                lastDirection = location.course
                saveCourse = false
            }
            
            if saveDistance && cameras.count > 0 {
                saveDistance = false
                //print("Distance Saved")
                for index in 0..<cameras.count {
                    let distance = Double(CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude).distance(from: CLLocation(latitude: cameras[index].latitude, longitude: cameras[index].longitude)))
                    savedDistanceToCamera[index] = distance
                    //print("Saved distance: \(savedDistanceToCamera[index])")
                }
            }
            
            lowerToBigger(location: location)
            
            checkCourse(course: location.course)
            sortByCourse()
            
            currentLocation.latitude = location.coordinate.latitude
            currentLocation.longitude = location.coordinate.longitude
            currentLocation.speed = Int(location.speed * 3.6 * 0.62)
            currentLocation.roadLimit = roadLimit
            currentLocation.course = location.course
            
//            print(currentLocation)
//            print(cameras)
//            print(removedCameras)
//            print(roadLimit)
//            print(allowUpdateLabels)
            print(sorted, parseRoad, cameras.count)
            
            if (getSpeedCameraBool && getSpeedCamera % 50 == 0) || getSpeedCamera == 2 {
                getCameraXML(location: CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude))
            }
            
            if getRoadBool && parseRoad % 10 == 0 {
                getRoad(location: CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude))
            }
            parseRoad += 1
            getSpeedCamera += 1
        }
        updateLabels()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let locationError = error as? CLError else {
            print(error)
            return
        }
        NSLog(locationError.localizedDescription)
    }
    
}

