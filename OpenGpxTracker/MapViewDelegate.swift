import MapKit
import CoreGPX

/// Handles all delegate functions of the GPX Mapview
///
class MapViewDelegate: NSObject, MKMapViewDelegate, UIAlertViewDelegate {

    /// The Waypoint is being edited (if there is any)
    var waypointBeingEdited: GPXWaypoint = GPXWaypoint()
    
    /// Displays a pin with whose annotation (bubble) will include delete and edit buttons.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation.isKind(of: MKUserLocation.self) {
            return nil
        }
        let annotationView: MKPinAnnotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "PinView")
        annotationView.canShowCallout = true
        annotationView.isDraggable = true
        //let detailButton: UIButton = UIButton.buttonWithType(UIButtonType.DetailDisclosure) as UIButton
        
        let deleteButton: UIButton = UIButton(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        deleteButton.setImage(UIImage(named: "delete"), for: UIControl.State())
        deleteButton.setImage(UIImage(named: "deleteHigh"), for: .highlighted)
        deleteButton.tag = kDeleteWaypointAccesoryButtonTag
        annotationView.rightCalloutAccessoryView = deleteButton
        
        let editButton: UIButton = UIButton(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        editButton.setImage(UIImage(named: "edit"), for: UIControl.State())
        editButton.setImage(UIImage(named: "editHigh"), for: .highlighted)
        editButton.tag = kEditWaypointAccesoryButtonTag
        annotationView.leftCalloutAccessoryView = editButton
        
        return annotationView
    }
    
    /// Displays the line for each segment
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay.isKind(of: MKTileOverlay.self) {
            return MKTileOverlayRenderer(overlay: overlay)
        }
        
        if overlay is MKPolyline {
            let pr = MKPolylineRenderer(overlay: overlay)
            pr.strokeColor = UIColor.blue.withAlphaComponent(0.5)
            pr.lineWidth = 3
            return pr
        }
        return MKOverlayRenderer()
    }
    
    /// Handles the actions of delete and edit button
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        print("calloutAccesoryControlTapped ")
        guard let waypoint = view.annotation as? GPXWaypoint else {
            return
        }
        
        guard let button = control as? UIButton else {
            return
        }
        
        guard let map = mapView as? GPXMapView else {
            return
        }
        
        switch button.tag {
        case kDeleteWaypointAccesoryButtonTag:
            print("[calloutAccesoryControlTapped: DELETE button] deleting waypoint with name \(waypoint.name ?? "''")")
            map.removeWaypoint(waypoint)
        case kEditWaypointAccesoryButtonTag:
            print("[calloutAccesoryControlTapped: EDIT] editing waypoint with name \(waypoint.name ?? "''")")
            
            let indexofEditedWaypoint = map.session.waypoints.firstIndex(of: waypoint)
            
            let alertController = UIAlertController(title: "Edit waypoint name", message: "Hint: To change the waypoint location drag and drop the pin", preferredStyle: .alert)
            alertController.addTextField { (textField) in
                textField.text = waypoint.title
                textField.clearButtonMode = .always
            }
            let saveAction = UIAlertAction(title: "Save", style: .default) { (action) in
                print("Edit waypoint alert view")
                self.waypointBeingEdited.title = alertController.textFields?[0].text
                map.coreDataHelper.update(toCoreData: self.waypointBeingEdited, from: indexofEditedWaypoint!)
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action) in }
            
            alertController.addAction(saveAction)
            alertController.addAction(cancelAction)
            
            UIApplication.shared.keyWindow?.rootViewController?.present(alertController, animated: true)
            
            self.waypointBeingEdited = waypoint
            
        default:
            print("[calloutAccesoryControlTapped ERROR] unknown control")
        }
    }
    
    
    /// Handles the change of the coordinates when a pin is dropped.
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView,
        didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
        let gpxMapView = mapView as! GPXMapView
        
        if newState == MKAnnotationView.DragState.ending {
            if let point = view.annotation as? GPXWaypoint {
                point.elevation = nil 
                if let index = gpxMapView.session.waypoints.firstIndex(of: point) {
                    gpxMapView.coreDataHelper.update(toCoreData: point, from: index)
                }
                
                print("Annotation name: \(String(describing: point.title)) lat:\(String(describing:point.latitude)) lon \(String(describing:point.longitude))")
            }
        }
    }
    
    
    /// Adds the pin to the map with an animation (comes from the top of the screen)
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        var i = 0
        let gpxMapView = mapView as! GPXMapView
        //adds the pins with an animation
        for object in views {
            i += 1
            let annotationView = object as MKAnnotationView
            //The only exception is the user location, we add to this the heading icon.
            if annotationView.annotation!.isKind(of: MKUserLocation.self) {
                if gpxMapView.headingImageView == nil {
                    let image = UIImage(named: "heading")!
                    gpxMapView.headingImageView = UIImageView(image: image)
                    gpxMapView.headingImageView!.frame = CGRect(x: (annotationView.frame.size.width - image.size.width)/2, y: (annotationView.frame.size.height - image.size.height)/2, width: image.size.width, height: image.size.height)
                    annotationView.insertSubview(gpxMapView.headingImageView!, at: 0)
                    gpxMapView.headingImageView!.isHidden = true
                }
                continue
            }
            let point: MKMapPoint = MKMapPoint.init(annotationView.annotation!.coordinate)
            if !mapView.visibleMapRect.contains(point) { continue }
            
            let endFrame: CGRect = annotationView.frame
            annotationView.frame = CGRect(x: annotationView.frame.origin.x, y: annotationView.frame.origin.y - mapView.superview!.frame.size.height,
                width: annotationView.frame.size.width, height:annotationView.frame.size.height)
            let interval: TimeInterval = 0.04 * 1.1
            UIView.animate(withDuration: 0.5, delay: interval, options: UIView.AnimationOptions.curveLinear, animations: { () -> Void in
                annotationView.frame = endFrame
                }, completion: { (finished) -> Void in
                    if finished {
                        UIView.animate(withDuration: 0.05, animations: { () -> Void in
                            //aV.transform = CGAffineTransformMakeScale(1.0, 0.8)
                            annotationView.transform = CGAffineTransform(a: 1.0, b: 0, c: 0, d: 0.8, tx: 0, ty: annotationView.frame.size.height*0.1)
                            
                            }, completion: { (finished: Bool) -> Void in
                                UIView.animate(withDuration: 0.1, animations: { () -> Void in
                                    annotationView.transform = CGAffineTransform.identity
                                })
                        })
                    }
            })
        }
    }
    
    ///
    /// Adds a small arrow image to the annotationView.
    /// This annotationView should be the MKUserLocation
    ///
    func addHeadingView(toAnnotationView annotationView: MKAnnotationView) {
           }
    
}
