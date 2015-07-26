//
//  BLSpinningProgressIndicator.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 28/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

class BLSpinningProgressIndicator : NSView {
    // MARK: Public Vars / Accessors
    var animating = false;
    var isAnimating:Bool {
        get {
            return self.animating;
        }
        set(animate) {
            if (animate == true) {
                self.startAnimation(self);
            }
            else {
                self.stopAnimation(self);
            }
        }
    }
    var indeterminate:Bool = true {
        didSet {
            if (self.indeterminate == true && self.isAnimating == true) {
                self.stopAnimation(self);
            }
            self.needsDisplay = true;
        }
    }
    var colour:NSColor? {
        get {
            return self.foreColour;
        }
        set {
            if (self.foreColour != newValue) {
                self.foreColour = newValue?.copy() as! NSColor;
                self.needsDisplay = true;
            }
        }
    }
    var backgroundColour:NSColor? {
        get {
            return self.backColour;
        }
        set {
            if (self.backColour != newValue) {
                self.backColour = newValue?.copy() as? NSColor;
                self.needsDisplay = true;
            }
        }
    }
    var drawsBackground:Bool? {
        get {
            return self.drawBackground;
        }
        set {
            if (self.drawBackground != newValue) {
                self.drawBackground = newValue;
            }
            self.needsDisplay = true;
        }
    }
    var doubleValue:Double? {
        get {
            return self.currentValue;
        }
        set {
            if (self.indeterminate == true) {
                self.indeterminate = false;
            }
            self.currentValue = newValue!;
            self.needsDisplay = true;
        }
    }
    var maxValue:Double = 100.0 {
        didSet {
            self.needsDisplay = true;
        }
    }
    var usesThreadedAnimation:Bool = false {
        didSet {
            if (self.usesThreadedAnimation != oldValue) {
                if (self.isAnimating == true) {
                    self.stopAnimation(self);
                    self.startAnimation(self);
                }
            }
        }
    }
    var lineWidth:CGFloat = 2.75;
    var lineStartOffset:CGFloat = 7.5;
    var lineEndOffset:CGFloat = 13.5;
    
    // MARK: - Private Vars
    var position:Int = 0;
    var numFins:Int = 12;
    var isFadingOut:Bool = false;
    var currentValue:Double = 0.0;
    var foreColour:NSColor = NSColor.blackColor().copy() as! NSColor;
    var backColour:NSColor?
    var animationThread:NSThread?
    var animationTimer:NSTimer?
    var drawBackground:Bool?
    
    override func viewDidMoveToWindow() {
        if (self.window == nil) {
            self.actuallyStopAnimation();
        }
        else if (self.isAnimating == true) {
            self.actuallyStartAnimation();
        }
    }
    
    override func drawRect(dirtyRect: NSRect) {
        var i:Int = 0;
        var alpha:Float = 1.0;
        
        var size:NSSize = self.bounds.size;
        var diameter:CGFloat = min(size.width, size.height);
        var scale:CGFloat = diameter / 32.0;
        
        if let drawBg = self.drawBackground {
            if (drawBg) {
                self.backColour?.set();
                NSBezierPath.fillRect(self.bounds);
            }
        }
        
        let contextPtr = NSGraphicsContext.currentContext()!.graphicsPort
        let currentContext = unsafeBitCast(contextPtr, CGContext.self)
        NSGraphicsContext.saveGraphicsState();
        
        CGContextTranslateCTM(currentContext, self.bounds.size.width / 2, self.bounds.size.height / 2);
        
        if (self.indeterminate == true) {
            
            var anglePerFin:CGFloat = CGFloat(Float(M_PI * 2) / Float(self.numFins));
            
            // Do initial rotation to start place
            var angle:CGFloat = (anglePerFin * CGFloat(self.position));
            CGContextRotateCTM(currentContext, angle);
            
            var lineWidth:CGFloat = self.lineWidth * scale;
            var lineStart:CGFloat = self.lineStartOffset * scale;
            var lineEnd:CGFloat   = self.lineEndOffset * scale;
            
            var path:NSBezierPath = NSBezierPath();
            path.lineWidth = lineWidth;
            path.lineCapStyle = NSLineCapStyle.RoundLineCapStyle;
            path.moveToPoint(NSMakePoint(0, lineStart));
            path.lineToPoint(NSMakePoint(0, lineEnd));
            
            for (i = 0; i < self.numFins; i++) {
                if (self.isAnimating == true) {
                    self.foreColour.colorWithAlphaComponent(CGFloat(alpha)).set();
                }
                else {
                    self.foreColour.colorWithAlphaComponent(0.2).set();
                }
                
                path.stroke();
                
                CGContextRotateCTM(currentContext, anglePerFin);
                alpha -= 1.0 / Float(self.numFins);
            }
        }
        else {
            var lineWidth:CGFloat = 1 + (0.01 * diameter);
            var circleRadius:CGFloat = (diameter - lineWidth) / 2.1;
            var circleCenter:NSPoint = NSZeroPoint;
            var completion:Double = self.currentValue / self.maxValue;
            
            self.foreColour.colorWithAlphaComponent(CGFloat(alpha)).set();
            
            var path:NSBezierPath = NSBezierPath();
            path.lineWidth = lineWidth;
            path.appendBezierPathWithOvalInRect(NSMakeRect(-circleRadius, -circleRadius, circleRadius * 2, circleRadius * 2));
            path.stroke();
            
            path = NSBezierPath();
            path.appendBezierPathWithArcWithCenter(circleCenter, radius: circleRadius, startAngle: 90.0, endAngle: 90.0 - (360.0 * CGFloat(completion)), clockwise: true);
            path.lineToPoint(circleCenter);
            path.fill();
        }
        
        NSGraphicsContext.restoreGraphicsState();
    }
    
    
    // MARK: - Class Methods
    func updateFrame(timer:NSTimer?) {
        self.position = (self.position - 1) % self.numFins;
        
        if (self.usesThreadedAnimation == true) {
            self.display();
        }
        else {
            self.needsDisplay = true;
        }
    }
    
    func animateInBackgroundThread() {
        var omega:Int = 100; // RPM
        var animationDelay:Int = 60 * 1000000 / omega / self.numFins;
        
        do {
            self.updateFrame(nil);
            usleep(useconds_t(animationDelay));
        } while(!NSThread.currentThread().cancelled);
    }
    
    func startAnimation(sender:AnyObject?) {
        if (self.indeterminate != true) {
            return;
        }
        if (self.isAnimating == true) {
            return;
        }
        
        self.actuallyStartAnimation();
        self.animating = true;
    }
    
    func actuallyStartAnimation() {
        // Just for safety
        self.actuallyStopAnimation();
        
        if (self.window != nil) {
            if (self.usesThreadedAnimation == true) {
                self.animationThread = NSThread(target: self, selector: "animateInBackgroundThread", object: nil);
                if let animThread = self.animationThread {
                    animThread.start();
                }
            }
            else {
                self.animationTimer = NSTimer(timeInterval: NSTimeInterval(0.05), target: self, selector: Selector("updateFrame:"), userInfo: nil, repeats: true);
                if let animTimer = self.animationTimer {
                    NSRunLoop.currentRunLoop().addTimer(animTimer, forMode: NSRunLoopCommonModes);
                    NSRunLoop.currentRunLoop().addTimer(animTimer, forMode: NSDefaultRunLoopMode);
                    NSRunLoop.currentRunLoop().addTimer(animTimer, forMode: NSEventTrackingRunLoopMode);
                }
            }
        }
    }
    
    func stopAnimation(sender:AnyObject?) {
        self.actuallyStopAnimation();
        self.animating = false;
    }
    
    func actuallyStopAnimation() {
        if let animThread = self.animationThread {
            animThread.cancel();
            if (animThread.finished) {
                NSRunLoop.currentRunLoop().runMode(NSModalPanelRunLoopMode, beforeDate: NSDate(timeIntervalSinceNow: 0.05));
            }
            self.animationThread = nil;
        }
        else if let animTimer = self.animationTimer {
            animTimer.invalidate();
            self.animationTimer = nil;
        }
    }
}
