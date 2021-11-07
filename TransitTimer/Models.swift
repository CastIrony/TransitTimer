//
//  Models.swift
//  TransitTimer
//
//  Created by Joel Bernstein on 11/5/21.
//

import Foundation
import CoreLocation
import UIKit

enum Model {
    struct Response: Codable, Equatable {
        let schedule: Schedule
        
        enum CodingKeys : String, CodingKey {
            case schedule = "resultSet"
        }
    }

    struct Schedule: Codable, Equatable{
        let arrivals: [Arrival]
        let stops: [Stop]
        let queryDate: Date
        
        var arrivalsByStopID: [Int : [Arrival]] = [:]
        var stopsByStopID: [Int : Stop] = [:]
        
        mutating func postProcess() {
            arrivalsByStopID = Dictionary(
                grouping: arrivals.filter {
                    $0.status == .estimated
                }.sorted {
                    $0.scheduledDate < $1.scheduledDate
                }, by: {
                    $0.stopID
                }
            )

            stopsByStopID = Dictionary(uniqueKeysWithValues: stops.map { ($0.stopID, $0) })
        }
        
        enum CodingKeys : String, CodingKey {
            case arrivals = "arrival"
            case stops = "location"
            case queryDate = "queryTime"
        }
    }

    struct Arrival: Codable, Identifiable, Equatable {
        let id: String
        private let routeID: Int
        let vehicleID: String?
        let stopID: Int
        private let fullSign: String
        let vehiclePosition: VehiclePosition?
        let scheduledDate: Date
        let estimatedDate: Date?
        let status: Status
                
        var route: Route {
            Route(routeID: routeID)
        }

        var displayName: String {
            let space = fullSign.range(of: "  ")
            let to = fullSign.range(of: " to ", options: [.caseInsensitive])
            
            var cutoffIndex: String.Index = fullSign.startIndex
            
            if self.route.isRail, let to = to {
                cutoffIndex = to.upperBound
            } else if let space = space {
                cutoffIndex = space.upperBound
            }
            
            return String(fullSign[cutoffIndex...])
        }
        
        enum CodingKeys : String, CodingKey {
            case id = "id"
            case routeID = "route"
            case fullSign
            case vehicleID
            case stopID = "locid"
            case vehiclePosition = "blockPosition"
            case scheduledDate = "scheduled"
            case estimatedDate = "estimated"
            case status
        }

        enum Status: String, Codable {
            case scheduled
            case estimated
            case canceled
        }
    }
    
    struct Route: Equatable {
        let routeID: Int
        var isRail: Bool {
            switch routeID {
            case 90, 100, 190, 193, 194, 200, 203, 208, 250: return true
            default: return false
            }
        }

        var iconName: String {
            isRail ? "tram.fill" : "bus.fill"
        }
        
        var symbol: String {
            switch routeID {
            case 90: return "Red"
            case 100: return "Blue"
            case 190: return "Yellow"
            case 193: return "NS"
            case 194: return "A"
            case 195: return "B"
            case 200: return "Green"
            case 203: return "WES"
            case 290: return "Orange"
            default: return String(routeID)
            }
        }

        var color: UIColor {
            switch routeID {
            case 90:  return UIColor(red: 1.0, green:0.4, blue:0.4, alpha:1.0)
            case 100: return UIColor(red: 0.4, green:0.6, blue:1.0, alpha:1.0)
            case 190: return UIColor(red: 1.0, green:0.8, blue:0.1, alpha:1.0)
            case 193: return UIColor(red: 0.6, green:0.8, blue:0.2, alpha:1.0)
            case 194: return UIColor(red: 0.0, green:0.7, blue:0.8, alpha:1.0)
            case 195: return UIColor(red: 0.0, green:0.7, blue:0.8, alpha:1.0)
            case 200: return UIColor(red: 0.1, green:0.9, blue:0.2, alpha:1.0)
            case 203: return UIColor(red: 0.7, green:0.7, blue:0.7, alpha:1.0)
            case 290: return UIColor(red: 0.9, green:0.4, blue:0.0, alpha:1.0)
            default:
                srand48(routeID)
                return UIColor(hue: drand48(), saturation: 0.45, brightness: 1, alpha: 1)
            }
        }
    }
    
    struct VehiclePosition: Codable, Equatable {
        private let latitude: Double
        private let longitude: Double
        let heading: Double?

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        enum CodingKeys : String, CodingKey {
            case latitude = "lat"
            case longitude = "lng"
            case heading
        }
    }

    struct Stop: Codable, Equatable {
        let stopID: Int
        let name: String
        private let latitude: Double
        private let longitude: Double
        let direction: Direction

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        
        enum CodingKeys : String, CodingKey {
            case stopID = "id"
            case name = "desc"
            case latitude = "lat"
            case longitude = "lng"
            case direction = "dir"
        }

        enum Direction: String, Codable {
            case northbound = "Northbound"
            case eastbound = "Eastbound"
            case southbound = "Southbound"
            case westbound = "Westbound"
        }
    }
}
