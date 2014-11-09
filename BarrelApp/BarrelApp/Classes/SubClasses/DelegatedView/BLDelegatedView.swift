//
//  BLDelegatedView.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 28/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

class BLDelegatedView : NSView {
    @IBOutlet
    var delegate:AnyObject!
    
    private var draggingEnteredResponse:NSDragOperation!
    
    // MARK: - Delegating drag-drop
    override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
        self.draggingEnteredResponse = NSDragOperation.None;
        if (self.delegate.respondsToSelector("draggingEntered:")) {
            self.draggingEnteredResponse = self.delegate.draggingEntered!(sender as NSDraggingInfo);
        }
        
        return self.draggingEnteredResponse;
    }
    
    override func wantsPeriodicDraggingUpdates() -> Bool {
        if (self.delegate.respondsToSelector("wantsPeriodicDraggingUpdates")) {
            return self.delegate.wantsPeriodicDraggingUpdates!();
        }
        else {
            return true;
        }
    }
    
    override func draggingUpdated(sender: NSDraggingInfo) -> NSDragOperation {
        if (self.delegate.respondsToSelector("draggingUpdated:")) {
            return self.delegate.draggingUpdated!(sender);
        }
        else {
            return self.draggingEnteredResponse;
        }
    }
    
    override func draggingExited(sender: NSDraggingInfo!) {
        if (self.delegate.respondsToSelector("draggingExited:")) {
            self.delegate.draggingExited!(sender);
        }
    }
    
    override func draggingEnded(sender: NSDraggingInfo!) {
        if (self.delegate.respondsToSelector("draggingEnded:")) {
            self.delegate.draggingEnded!(sender);
        }
    }
    
    override func prepareForDragOperation(sender: NSDraggingInfo) -> Bool {
        if (self.delegate.respondsToSelector("prepareForDragOperation:")) {
            return self.delegate.prepareForDragOperation!(sender);
        }
        else {
            return true;
        }
    }
    
    override func performDragOperation(sender: NSDraggingInfo) -> Bool {
        if (self.delegate.respondsToSelector("performDragOperation:")) {
            return self.delegate.performDragOperation!(sender);
        }
        else {
            return false;
        }
    }
    
    override func concludeDragOperation(sender: NSDraggingInfo!) {
        if (self.delegate.respondsToSelector("concludeDragOperation:")) {
            self.delegate.concludeDragOperation!(sender);
        }
    }
}
