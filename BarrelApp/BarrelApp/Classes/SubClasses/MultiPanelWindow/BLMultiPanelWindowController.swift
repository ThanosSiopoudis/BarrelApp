//
//  BLMultiPanelWindowController.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 27/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

class BLMutliPanelWindowController: NSWindowController {
    var currentPanel:NSView? {
        get {
            return self.panelContainer?.subviews.lastObject as? NSView;
        }
        set {
            var oldPanel:NSView? = self.currentPanel;
            
            if (newValue == nil) {
                oldPanel?.removeFromSuperview();
            }
            else if (oldPanel != newValue) {
                var newFrame:NSRect = self.window.frame;
                var oldFrame:NSRect = self.window.frame;
                
                var newSize:NSSize = newValue!.frame.size;
                var oldSize:NSSize = self.panelContainer!.frame.size;
                
                var difference:NSSize = NSMakeSize(newSize.width - oldSize.width, newSize.height - oldSize.height);
                newFrame.origin = NSMakePoint(oldFrame.origin.x, oldFrame.origin.y - difference.height);
                newFrame.size   = NSMakeSize(oldFrame.size.width + difference.width, oldFrame.size.height + difference.height);
                
                if (oldPanel != nil && self.window.visible) {
                    self.panelContainer?.addSubview(newValue!, positioned: NSWindowOrderingMode.Below, relativeTo: oldPanel!);
                    var animation:NSViewAnimation = self.transitionFromPanel(oldPanel, toPanel: newValue);
                    
                    var resize:NSDictionary = [
                        NSViewAnimationTargetKey: self.window,
                        NSViewAnimationEndFrameKey: NSValue(rect: newFrame)
                    ];
                    
                    var viewAnimations:NSArray = animation.viewAnimations as NSArray;
                    animation.viewAnimations = viewAnimations.arrayByAddingObject(resize);
                    animation.animationBlockingMode = NSAnimationBlockingMode.Blocking;
                    animation.startAnimation();
                    
                    oldPanel?.removeFromSuperview();
                    oldPanel?.frame.size = NSSizeToCGSize(oldSize);
                    oldPanel?.hidden = false;
                    newValue?.display();
                }
                else {
                    oldPanel?.removeFromSuperview();
                    self.window.setFrame(newFrame, display: true);
                    self.panelContainer?.addSubview(newValue!);
                }
                
                self.window.makeFirstResponder(newValue?.nextKeyView);
            }
        }
    }
    
    @IBOutlet
    var panelContainer:NSView?
    
    func hidePanel(oldPanel:NSView?, andFadeInPanel:NSView?) -> NSViewAnimation {
        var fadeIn:NSDictionary = [
            NSViewAnimationTargetKey: andFadeInPanel!,
            NSViewAnimationEffectKey: NSViewAnimationFadeInEffect
        ];
        
        oldPanel?.hidden = true;
        var animation:NSViewAnimation = NSViewAnimation(viewAnimations: [fadeIn]);
        return animation;
    }
    
    func transitionFromPanel(oldPanel:NSView?, toPanel:NSView?) -> NSViewAnimation {
        var animation:NSViewAnimation = self.hidePanel(oldPanel, andFadeInPanel: toPanel);
        animation.duration = 0.25;
        return animation;
    }
}
