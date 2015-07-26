//
//  BLTabbedWindowController.swift
//  BarrelApp
//
//  Created by Thanos Siopoudis on 25/08/2014.
//  Copyright (c) 2014 AppCake Limited. All rights reserved.
//

import Cocoa

class BLTabbedWindowController : NSWindowController, NSTabViewDelegate, NSToolbarDelegate {
    let BLTabbedWindowControllerTransitionDuration = 0.25;
    
    @IBOutlet
    var tabView:NSTabView!
    @IBOutlet
    var toolbarForTabs:NSToolbar!
    var animatesTabTransitionsWithFade:Bool = true;
    
    override func windowDidLoad() {
        var selectedItem:NSTabViewItem? = self.tabView.selectedTabViewItem;
        if (selectedItem != nil) {
            self.tabView(self.tabView, willSelectTabViewItem: selectedItem);
            self.tabView(self.tabView, didSelectTabViewItem: selectedItem);
        }
    }
    
    func selectedTabviewItemIndex() -> NSInteger {
        var selectedItem:NSTabViewItem? = self.tabView.selectedTabViewItem;
        if ((selectedItem) != nil) {
            return self.tabView.indexOfTabViewItem(selectedItem!);
        }
        else {
            return NSNotFound;
        }
    }
    
    func setSelectedTabViewItemIndex(tabIndex:NSInteger) {
        self.tabView.selectTabViewItemAtIndex(tabIndex);
    }
    @IBAction func takeSelectedTabViewItemByTag(sender: AnyObject) {
        self.tabView.selectTabViewItemAtIndex(sender.tag());
    }
    
    @IBAction func takeSelectedTabViewItemFromSegment(sender:NSSegmentedControl) {
        let cell:NSSegmentedCell = sender.cell() as! NSSegmentedCell;
        var selectedTag:NSInteger = cell.tagForSegment(sender.selectedSegment);
        self.tabView.selectTabViewItemAtIndex(selectedTag);
    }
    
    // MARK: - NSTabView Delegate
    func tabView(tabView: NSTabView, willSelectTabViewItem tabViewItem: NSTabViewItem?) {
        var currentItem:NSTabViewItem = tabView.selectedTabViewItem!;
        
        var newView:NSView = tabViewItem!.view!.subviews.lastObject as! NSView;
        var oldView:NSView = currentItem.view!.subviews.lastObject as! NSView;
        
        var newSize:NSSize = newView.frame.size;
        var oldSize:NSSize = tabView.frame.size;
        var difference:NSSize = NSMakeSize(newSize.width - oldSize.width, newSize.height - oldSize.height);
        
        // Generate a new window frame that can contain the new panel,
        // Ensuring that the top left corner stays put
        var newFrame:NSRect = self.window!.frame;
        var oldFrame:NSRect = self.window!.frame;
        newFrame.origin = NSMakePoint(oldFrame.origin.x, oldFrame.origin.y - difference.height);
        newFrame.size = NSMakeSize(oldFrame.size.width + difference.width, oldFrame.size.height + difference.height);
        
        if ((currentItem != tabViewItem) && self.window!.visible) {
            // The tab-view loses the first responder when we hide the original view,
            // so we restore it once we've finished animating
            var firstResponder:NSResponder! = self.window!.firstResponder;
            
            // if a fade transition is enabled, synchronise the resizing and fading animations
            if (self.animatesTabTransitionsWithFade) {
                oldView.hidden = false;
                newView.hidden = false;
                var resize:NSDictionary = [
                    NSViewAnimationTargetKey: self.window!,
                    NSViewAnimationEndFrameKey: NSValue(rect: newFrame)
                ];
                
                var fadeOut:NSDictionary = [
                    NSViewAnimationTargetKey: oldView,
                    NSViewAnimationFadeOutEffect: NSViewAnimationEffectKey
                ];
                
                var fadeIn:NSDictionary = [
                    NSViewAnimationTargetKey:newView,
                    NSViewAnimationFadeInEffect: NSViewAnimationEffectKey
                ];
                
                var animation:NSViewAnimation = NSViewAnimation(viewAnimations: [fadeOut, fadeIn, resize]);
                animation.duration = BLTabbedWindowControllerTransitionDuration;
                animation.animationBlockingMode = NSAnimationBlockingMode.Blocking;
                
                animation.startAnimation();
                oldView.hidden = false;
            }
            else if (!NSEqualRects(oldFrame, newFrame)) {
                // Otherwise we need to resize the window, then hide the original view
                // while animating the resize
                oldView.hidden = true;
                var resize:NSDictionary = [
                    NSViewAnimationTargetKey: self.window!,
                    NSViewAnimationEndFrameKey: NSValue(rect: newFrame)
                ];
                
                // IMPLEMENTATION NOTE: We could just use setFrame:display:animate:,
                // but we want a constant speed between tab transitions
                var animation:NSViewAnimation = NSViewAnimation(viewAnimations: [resize]);
                animation.duration = BLTabbedWindowControllerTransitionDuration;
                animation.animationBlockingMode = NSAnimationBlockingMode.Blocking;
                
                animation.startAnimation();
                oldView.hidden = false;
            }
            
            // Restore the first responder
            self.window!.makeFirstResponder(firstResponder);
        }
        else {
            self.window!.setFrame(newFrame, display: true);
        }
    }
    
    func tabView(tabView: NSTabView, didSelectTabViewItem tabViewItem: NSTabViewItem?) {
        // Sync the toolbar selection after switching tabs
        self.toolbarForTabs.selectedItemIdentifier = tabViewItem!.identifier as? String;
        
        // Sync the window title to the selected tab's label if desired
        var tabLabel:String! = tabViewItem!.label;
        if (tabLabel != nil && self.shouldSyncWindowTitleToTabLabel(tabLabel)) {
            self.window!.title = self.windowTitleForDocumentDisplayName(tabLabel);
        }
    }
    
    func shouldSyncWindowTitleToTabLabel(label:String) -> Bool {
        return false;
    }
    
    // MARK: - NSToolbarDelegate Methods
    func toolbarWillAddItem(notification: NSNotification) {
        var item:NSToolbarItem!
        if let info = notification.userInfo {
            item = info["item"] as! NSToolbarItem;
        }
        else { return; }
        
        var tag:NSInteger = item.tag;
        var numTabs:NSInteger = self.tabView.tabViewItems.count;
        if (tag > -1 && tag < numTabs) {
            var matchingTab = self.tabView.tabViewItemAtIndex(tag);
            matchingTab.identifier = item.itemIdentifier;
            
            // If this tab was selected, mark the toolbar item as selected also
            if (self.tabView.selectedTabViewItem == matchingTab) {
                self.toolbarForTabs.selectedItemIdentifier = item.itemIdentifier;
            }
        }
    }
    
    func toolbarSelectableItemIdentifiers(toolbar: NSToolbar) -> [AnyObject] {
        var tabs:NSArray = self.tabView.tabViewItems;
        var identifiers:NSMutableArray = NSMutableArray(capacity: tabs.count);
        for tab in tabs {
            identifiers.addObject(tab.identifier);
        }
        return identifiers as [AnyObject];
    }
}
