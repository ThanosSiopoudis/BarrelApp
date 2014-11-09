//
//  NSRect+Geometry.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 28/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

extension NSRect {
    static func alignInRectWithAnchor(innerRect:NSRect, outerRect:NSRect, anchor:NSPoint) -> NSRect {
        var alignedRect:NSRect = innerRect;
        alignedRect.origin.x = outerRect.origin.x + (anchor.x * (outerRect.size.width - innerRect.size.width));
        alignedRect.origin.y = outerRect.origin.y + (anchor.y * (outerRect.size.height - innerRect.size.height));
        return alignedRect;
    }

    static func centerInRect(innerRect:NSRect, outerRect:NSRect) -> NSRect {
        return self.alignInRectWithAnchor(innerRect, outerRect: outerRect, anchor: NSMakePoint(0.5, 0.5));
    }
}
