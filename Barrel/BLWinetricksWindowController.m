/*
 Copyright (c) 2013, Barrel Team
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of the Barrel Team nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY Barrel Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL Barrel Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "OEButton.h"
#import "BLWinetricksWindowController.h"

@interface BLWinetricksWindowController () {
    IBOutlet NSView         *winetricksView;
    IBOutlet NSOutlineView  *winetricksOutline;
    IBOutlet OEButton       *executeWinetricksBtn;
    IBOutlet OEButton       *cancelWindowBtn;
    
    NSString                *winetricksPlistPath;
    NSMutableDictionary     *winetricksDatasource;
}

@property (nonatomic, readwrite) NSString *winetricksPlistPath;
@property (nonatomic, readwrite) NSMutableDictionary *winetricksDatasource;

@end

@implementation BLWinetricksWindowController
@synthesize winetricksPlistPath, winetricksDatasource;

- (id)init
{
    self = [super initWithWindowNibName:@"Winetricks"];
    if (self) {
        // Read the winetricks .plist file
        
    }
    
    return self;
}

- (id)initWithPlistPath:(NSString *)plistPath
{
    self = [super initWithWindowNibName:@"Winetricks"];
    if (self) {
        [self setWinetricksPlistPath:plistPath];
        [self setWinetricksDatasource:[[NSMutableDictionary alloc] init] ];
        
        // Read the plist file and render the items in the outline view
        NSMutableDictionary *infoPlist = [[NSMutableDictionary alloc] initWithContentsOfFile:[self winetricksPlistPath]];
        
        // Create a compatible array
        NSArray *items = [infoPlist objectForKey:@"winetricks"];
        for (NSMutableDictionary *item in items) {
            if ([[self winetricksDatasource] objectForKey:[item objectForKey:@"category"]] == nil) {
                [[self winetricksDatasource] setObject:[NSMutableArray arrayWithObject:item] forKey:[item objectForKey:@"category"]];
            }
            else {
                NSMutableArray *inArray = [[self winetricksDatasource] objectForKey:[item objectForKey:@"category"]];
                [inArray addObject:item];
            }
        }
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [[[winetricksOutline tableColumns] objectAtIndex:0] setIdentifier:@"install"];
    [[[winetricksOutline tableColumns] objectAtIndex:1] setIdentifier:@"winetrick"];
    [[[winetricksOutline tableColumns] objectAtIndex:2] setIdentifier:@"description"];
}

#pragma mark Datasource and Delegate methods
// Method returns count of children for given tree node item
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    NSInteger cnt = 0;
    if (item == nil) { // root
        cnt = [[winetricksDatasource allKeys] count];
    }
    else {
        cnt = [[[self winetricksDatasource] objectForKey:item] count];
    }
    return cnt;
}

// Method returns flag, whether we can expand given tree node item or not
// (here is the simple rule, we can expand only nodes having one and more children)
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    NSInteger children = [[[self winetricksDatasource] objectForKey:item] count];
    return children > 1 ? YES : NO;
}

// Method returns value to be shown for given column of the tree node item
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    if ([[[self winetricksDatasource] objectForKey:item] isKindOfClass:[NSArray class]]) {
        if ([[[tableColumn headerCell] stringValue] isEqualToString:@"Winetrick"]) {
            return [item capitalizedString];
        }
        else if ([[[tableColumn headerCell] stringValue] isEqualToString:@"Install"]) {
            return nil;
        }
        else {
            return @"";
        }
    }
    else {
        if ([[tableColumn identifier] isEqualToString:@"winetrick"]) {
            return [item objectForKey:@"winetrick"];
        }
        else if ([[tableColumn identifier] isEqualToString:@"description"]) {
            return [item objectForKey:@"title"];
        }
        else {
            return @"";
        }
    }
}

- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    NSCell *returnCell = [tableColumn dataCell];
    
    if ([[[tableColumn headerCell] stringValue] isEqualToString:@"Install"] && [item isKindOfClass:[NSString class]]) {
        returnCell = [[NSCell alloc] initTextCell:@""];
    }
    
    return returnCell;
}

// Method returns children item for given tree node item by given index
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (item == nil) {
        // Get the key by index
        NSArray *keys = [[self winetricksDatasource] allKeys];
        NSString *theKey = [keys objectAtIndex:index];
        return theKey;
    }
    else {
        NSArray *items = [[self winetricksDatasource] objectForKey:item];
        return [items objectAtIndex:index];
    }
}
#pragma mark ---
#pragma mark Interface Actions
- (IBAction)executeWinetricks:(id)sender {
    
}
#pragma mark ---
@end
