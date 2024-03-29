//
//  OverpassRelation.swift
//  SwiftOverpass
//
//  Created by Sho Kamei on 2017/12/03.
//  Copyright © 2017年 Sho Kamei. All rights reserved.
//

import Foundation

public final class OverpassRelation {
    
    // MARK: - Constants
    
    /// Represents a <member> element
    public struct Member {
        let type: OverpassQueryType
        let id: String
        let role: String?
    }
    
    // MARK: - Properties
    
    /// The response which made the relation
    public fileprivate(set) weak var response: OverpassResponse?
    /// The id of the way
    public let id: String
    /// List of member the relation has
    public let members: [Member]?
    /// List of tag the node has
    public let tags: [String : String]
    
    // MARK: - Initializers
    
    /**
     Creates a `OverpassRelation`
    */
    internal init(id: String, members: [Member]?, tags: [String : String], response: OverpassResponse) {
        self.id = id
        self.members = members
        self.tags = tags
        self.response = response
    }
    
    // MARK: - Public
    
    /**
     Returns nodes that related to the relation after load from response
     */
    public func loadRelatedNodes() -> [OverpassNode]? {
        if let response = response, let allNodes = response.nodes, let members = members {
            let nodeIds = members.filter { $0.type == .node }
                .map { $0.id }
            
            var filtered = [OverpassNode]()
            nodeIds.forEach { id in
                if let index = allNodes.firstIndex(where: { $0.id == id }) {
                    filtered.append(allNodes[index])
                    return
                }
            }
            
            // Returns if it has some nodes.
            if filtered.count > 0 {
                return filtered
            }
        }
        
        return nil
    }
    
    /**
     Return ways that related to the relation after load from response
    */
    public func loadRelatedWays() -> [OverpassWay]? {
        if let response = response, let allWays = response.ways, let members = members {
            let wayIds = members.filter { $0.type == .way }
                .map { $0.id }
            
            var filtered = [OverpassWay]()
            wayIds.forEach { id in
                if let index = allWays.firstIndex(where: { $0.id == id }) {
                    filtered.append(allWays[index])
                    return
                }
            }
            
            // Returns if it has some nodes.
            if filtered.count > 0 {
                return filtered
            }
        }
        
        return nil
    }
    
    /**
     Return another relations that related to the relation after load from response
    */
    public func loadRelatedRelations() -> [OverpassRelation]? {
        if let response = response, let allRels = response.relations, let members = members {
            let relIds = members.filter { $0.type == .relation }
                .map { $0.id }
            
            var filtered = [OverpassRelation]()
            relIds.forEach { id in
                if let index = allRels.firstIndex(where: { $0.id == id }) {
                    filtered.append(allRels[index])
                    return
                }
            }
            
            // Returns if it has some nodes.
            if filtered.count > 0 {
                return filtered
            }
        }
        
        return nil
    }
}
