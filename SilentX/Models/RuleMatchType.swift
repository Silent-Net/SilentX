//
//  RuleMatchType.swift
//  SilentX
//
//  Routing rule match type enumeration
//

import Foundation

/// Types of matching criteria for routing rules
enum RuleMatchType: String, Codable, CaseIterable, Identifiable {
    case domain = "domain"
    case domainSuffix = "domain_suffix"
    case domainKeyword = "domain_keyword"
    case ipCIDR = "ip_cidr"
    case geoIP = "geoip"
    case process = "process_name"
    
    var id: String { rawValue }
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .domain: return "Domain"
        case .domainSuffix: return "Domain Suffix"
        case .domainKeyword: return "Domain Keyword"
        case .ipCIDR: return "IP CIDR"
        case .geoIP: return "GeoIP"
        case .process: return "Process Name"
        }
    }
    
    /// Placeholder text for input field
    var placeholder: String {
        switch self {
        case .domain: return "example.com"
        case .domainSuffix: return ".example.com"
        case .domainKeyword: return "google"
        case .ipCIDR: return "192.168.1.0/24"
        case .geoIP: return "US"
        case .process: return "Safari"
        }
    }
    
    /// Description of the match type
    var description: String {
        switch self {
        case .domain: return "Exact domain match"
        case .domainSuffix: return "Domain ends with value"
        case .domainKeyword: return "Domain contains value"
        case .ipCIDR: return "IP address in CIDR range"
        case .geoIP: return "GeoIP country code"
        case .process: return "Process name match"
        }
    }
    
    /// SF Symbol name for the match type
    var systemImage: String {
        switch self {
        case .domain: return "globe"
        case .domainSuffix: return "text.append"
        case .domainKeyword: return "magnifyingglass"
        case .ipCIDR: return "number"
        case .geoIP: return "map"
        case .process: return "app"
        }
    }
}
