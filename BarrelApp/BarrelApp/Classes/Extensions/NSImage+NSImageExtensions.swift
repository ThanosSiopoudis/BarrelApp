//
//  NSImage+NSImageExtensions.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 29/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

extension NSImage {
    func flipVertically() -> NSImage? {
        var existingImage:NSImage = self;
        var existingSize:NSSize = existingImage.size;
        var newSize:NSSize = NSMakeSize(existingSize.width, existingSize.height);
        var flippedImage:NSImage = NSImage(size: newSize);

        flippedImage.lockFocus();
        var transform:NSAffineTransform = NSAffineTransform();
        transform.scaleXBy(1.0, yBy: -1.0);
        transform.translateXBy(0.0, yBy: existingSize.height);
        transform.concat();

        self.drawAtPoint(NSZeroPoint, fromRect: NSMakeRect(0.0, 0.0, newSize.width, newSize.height), operation: NSCompositingOperation.CompositeCopy, fraction: 1.0);
        flippedImage.unlockFocus();

        return flippedImage;
    }
}
