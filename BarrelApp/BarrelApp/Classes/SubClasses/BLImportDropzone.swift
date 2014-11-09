//
//  BLImportDropzone.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 28/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

var icon:NSImage? = nil;
var dropShadow:NSShadow? = nil;
var dropHighlight:NSShadow? = nil;

class BLImportDropzone : NSButton {
    let BLImportDropzoneBorderAnimationLoops:CGFloat = 1000.0;
    
    var borderPhase:CGFloat {
        didSet {
            self.borderPhase = self.borderPhase % 18;
            self.setNeedsDisplay();
        }
    }
    var borderOutset:CGFloat {
        didSet {
            self.setNeedsDisplay();
        }
    }
    
    
    override var image:NSImage! {
        didSet {
            self.highlighted = false;
        }
    }
    
    override var highlighted:Bool {
        didSet {
            if (self.highlighted != oldValue) {
                if (self.highlighted) {
                    var maxPhase:CGFloat = 18.0 * self.BLImportDropzoneBorderAnimationLoops;
                    var duration:CFTimeInterval = 1.0 * Double(self.BLImportDropzoneBorderAnimationLoops);
                    
//                    NSAnimationContext.runAnimationGroup({context in
//                        context.duration = duration;
//                        self.animator().borderPhase = maxPhase;
//                    }, completionHandler: nil);
                    
//                    var basicAnim:CABasicAnimation = CABasicAnimation(keyPath: "borderOutset");
//                    basicAnim.fromValue = self.borderOutset;
//                    basicAnim.toValue = 8.0;
//                    basicAnim.duration = duration;
//                    self.layer?.addAnimation(basicAnim, forKey: "borderOutset");
                }
                else {
                    self.borderPhase = 0.0;
                    self.borderOutset = 0.0;
                }
            }
        }
    }
    
    required init?(coder: NSCoder) {
        self.borderPhase = 0.0;
        self.borderOutset = 0.0;
        
        super.init(coder: coder);
    }
    
    override class func defaultAnimationForKey(key:String) -> AnyObject? {
        if (key == "borderOutset") {
            return CABasicAnimation();
        }
        if (key == "borderPhase") {
            return CABasicAnimation();
        }
        return superclass()!.defaultAnimationForKey(key);
    }
    
    class func dropzoneIcon() -> NSImage? {
        if (icon == nil) {
            icon = NSImage(named: "DropzoneTemplate")!.copy() as? NSImage;
            var tint:NSColor = NSColor.whiteColor();
            
            var bounds:NSRect = NSZeroRect;
            bounds.size = icon!.size;
            
            icon!.lockFocus();
            tint.set();
            NSRectFillUsingOperation(bounds, NSCompositingOperation.CompositeSourceAtop);
            icon!.unlockFocus();
        }
        
        return icon;
    }
    
    class func dropzoneShadow() -> NSShadow? {
        if (dropShadow == nil) {
            dropShadow = NSShadow();
            dropShadow?.shadowOffset = NSMakeSize(0.0, 0.0);
            dropShadow?.shadowBlurRadius = 3.0;
            dropShadow?.shadowColor = NSColor.blackColor().colorWithAlphaComponent(0.5);
        }
        
        return dropShadow;
    }
    
    class func dropzoneHighlight() -> NSShadow? {
        if (dropHighlight == nil) {
            dropHighlight = NSShadow();
            dropHighlight?.shadowOffset = NSMakeSize(0.0, 0.0);
            dropHighlight?.shadowBlurRadius = 3.0;
            dropHighlight?.shadowColor = NSColor.whiteColor().colorWithAlphaComponent(0.5);
        }
        
        return dropHighlight;
    }
    
    class func borderForFrame(frame:NSRect, phase:CGFloat) -> NSBezierPath? {
        var pattern:[CGFloat] = [12.0, 6.0];
        var borderWidth:CGFloat = 4.0;
        
        let newframe = NSIntegralRect(frame);
        var insetFrame:NSRect = NSInsetRect(newframe, borderWidth / 2, borderWidth / 2);
        var border:NSBezierPath = NSBezierPath(roundedRect: insetFrame, xRadius: borderWidth, yRadius: borderWidth);
        border.lineWidth = borderWidth;
        border.setLineDash(pattern, count: 2, phase: phase);
        
        return border;
    }
    
    override func viewDidMoveToSuperview() {
        if (self.superview == nil) {
            self.highlighted = false;
        }
    }
    
    override func drawRect(dirtyRect: NSRect) {
        NSBezierPath.clipRect(dirtyRect);
        self.drawDropZoneInRect(dirtyRect);
    }
    
    func drawDropZoneInRect(dirtyRect:NSRect) {
        
        var borderColour:NSColor = NSColor.whiteColor();
        var icon:NSImage? = BLImportDropzone.dropzoneIcon();
        var dropzoneShadow:NSShadow?
        var selfCell:NSButtonCell = self.cell() as NSButtonCell;
        
        if (self.highlighted || selfCell.highlighted) {
            dropzoneShadow = BLImportDropzone.dropzoneHighlight();
        }
        else {
            dropzoneShadow = BLImportDropzone.dropzoneShadow();
        }
        
        var borderInset:CGFloat = 8.0 - self.borderOutset;
        var borderFrame:NSRect = NSInsetRect(self.bounds, borderInset, borderInset);
        
        var shadowRadius:CGFloat = dropzoneShadow!.shadowBlurRadius;
        borderFrame = NSInsetRect(borderFrame, shadowRadius, shadowRadius);
        
        var imageFrame:NSRect = NSZeroRect;
        imageFrame.size = icon!.size;
        imageFrame = NSIntegralRect(NSRect.centerInRect(imageFrame, outerRect: self.bounds));
        
        NSGraphicsContext.saveGraphicsState();
        dropzoneShadow!.set();
        if (NSIntersectsRect(dirtyRect, borderFrame)) {
            borderColour.set();
            var border:NSBezierPath? = BLImportDropzone.borderForFrame(borderFrame, phase: borderPhase);
            border!.stroke();
        }
        
        if (NSIntersectsRect(dirtyRect, imageFrame)) {
            icon!.drawInRect(imageFrame, fromRect: NSZeroRect, operation: NSCompositingOperation.CompositeSourceOver, fraction: 1.0, respectFlipped: true, hints: nil);
        }
        NSGraphicsContext.restoreGraphicsState();
    }
}
