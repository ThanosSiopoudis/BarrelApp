//
//  NSView+DrawingHelpers.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 28/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

extension NSView {
    func offsetFromWindowOrigin() -> NSPoint {
        var offset:NSPoint = NSZeroPoint;
        var offsetParent:NSView? = self;
        
        while let oParent = offsetParent {
            offset = NSPoint.newPointWithDelta(offset, delta: oParent.frame.origin);
            offsetParent = offsetParent?.superview;
        }

        return offset;
    }
}
