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

#import "BLGameImporter.h"
#import "BLImportItem.h"

#import "NSArray+OEAdditions.h"
#import "NSURL+OELibraryAdditions.h"

#import "OEHUDAlert.h"
#import "OEHUDAlert+DefaultAlertsAdditions.h"

#import "AppCakeAPI.h"

static const int MaxSimultaneousImports = 1; // imports can't really be simultaneous because access to queue is not ready for multithreadding right now

#pragma mark Error Codes -
NSString *const BLImportErrorDomainFatal        = @"BLImportFatalDomain";
NSString *const BLImportErrorDomainResolvable   = @"BLImportResolvableDomain";
NSString *const BLImportErrorDomainSuccess      = @"BLImportSuccessDomain";

NSString *const BLImportInfoSystemID            = @"systemID";
NSString *const BLImportInfoCollectionID        = @"collectionID";

@interface BLGameImporter ()
{
    dispatch_queue_t dispatchQueue;
}

@property(readwrite)            NSInteger          status;
@property(readwrite)            NSInteger          activeImports;
@property(readwrite)            NSInteger          numberOfProcessedItems;
@property(readwrite, nonatomic) NSInteger          totalNumberOfItems;
@property(readwrite)            NSMutableArray    *queue;
@property(weak)                 OELibraryDatabase *database;
@property(readwrite)            OEHUDAlert        *progressWindow;
@property(readwrite)            NSString          *volumeName;
@property(readwrite)            AppCakeAPI        *appCake;
@property(readwrite)            BLImportItem      *currentItem;
@property(readwrite)            OEHUDAlert        *alertCache;

- (void)processNextItemIfNeeded;

#pragma mark - Import Steps
- (void)performImportStepCheckVolume:(BLImportItem *)item;
- (void)performImportStepCheckDirectory:(BLImportItem *)item;
- (void)performImportStepLookupEntry:(BLImportItem *)item;
- (void)performImportStepDownloadBundle:(BLImportItem *)item;

- (void)scheduleItemForNextStep:(BLImportItem *)item;
- (void)stopImportForItem:(BLImportItem *)item withError:(NSError *)error;
- (void)cleanupImportForItem:(BLImportItem *)item;
- (void)reSearchItem:(BLImportItem *)item;

@end

@implementation BLGameImporter
@synthesize database, delegate;

+ (void)initialize
{
    if (self != [BLGameImporter class]) return;
    [[NSUserDefaults standardUserDefaults] registerDefaults:(@{
                                                             OEOrganizeLibraryKey: @(YES),
                                                             OECopyToLibraryKey: @(YES),OEAutomaticallyGetInfoKey: @(YES),
                                                             })];
}

- (id)initWithDatabase:(OELibraryDatabase *)aDatabase
{
    self = [super init];
    if (self) {
        [self setDatabase:aDatabase];
        [self setQueue:[NSMutableArray array]];
        
        dispatchQueue = dispatch_queue_create("com.appcake.importqueue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_t priority = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
        dispatch_set_target_queue(dispatchQueue, priority);
        [self setStatus:BLImporterStatusStopped];
    }
    return self;
}

- (void)processNextItemIfNeeded
{
    IMPORTDLog(@"%s && %s -> -processNextItem", BOOL_STR([self status] == BLImporterStatusRunning), BOOL_STR([self activeImports] < MaxSimultaneousImports));
    if ([self status] == BLImporterStatusRunning && [self activeImports] < MaxSimultaneousImports)
    {
        [self processNextItem];
    }
}

- (void)processNextItem
{
    self.activeImports++;
    IMPORTDLog(@"activeImports: %ld", self.activeImports);
    
    BLImportItem *nextItem = [[self queue] firstObjectMatchingBlock:^BOOL (id evaluatedObject)
                             {
                                 return [evaluatedObject importState] == BLImportItemStatusIdle;
                             }];
    if (nextItem != nil)
    {
        [nextItem setImportState:BLImportItemStatusActive];
        dispatch_async(dispatchQueue, ^{
            importBlock(self, nextItem);
        });
        
        if (MaxSimultaneousImports > 1) dispatch_async(dispatchQueue, ^{
            [self processNextItemIfNeeded];
        });
    }
    else
    {
        self.activeImports--;
        if ([self numberOfProcessedItems] == [self totalNumberOfItems])
        {
            dispatch_async(dispatchQueue, ^{
                if ([[self queue] count] == 0)
                {
                    [self setQueue:[NSMutableArray array]];
                    [self setNumberOfProcessedItems:0];
                    [self setTotalNumberOfItems:0];
                    [self setStatus:BLImporterStatusStopped];
                }
                else
                    [self processNextItemIfNeeded];
            });
        }
    }
}

- (void)dealloc
{
    dispatch_release(dispatchQueue);
}

#pragma mark - Import Block
static void importBlock(BLGameImporter *importer, BLImportItem *item)
{
    @autoreleasepool {
        IMPORTDLog(@"Status: %ld | Step: %d | URL: %@", [importer status], [item importStep], [item sourceURL]);
        if ([importer status] == BLImporterStatusPausing || [importer status] == BLImporterStatusPaused)
        {
            DLog(@"skipping item!");
            importer.activeImports--;
            if ([item importState] == BLImportItemStatusActive)
                [item setImportState:BLImportItemStatusIdle];
        }
        else if ([importer status] == BLImporterStatusStopping || [importer status] == BLImporterStatusStopping)
        {
            importer.activeImports--;
            [item setError:nil];
            [item setImportState:BLImportItemStatusCancelled];
            // [importer cleanupImportForItem: item];
            DLog(@"Deleting item...");
        }
        else
        {
            // Do we need to wait?
            if ([item importState] != BLImportItemStatusWait) {
                switch ([item importStep])
                {
                    case BLImportStepCheckVolume:
                        [importer performImportStepCheckVolume:item];
                        break;
                    case BLImportStepCheckDirectory:
                        [importer performImportStepCheckDirectory:item];
                        break;
                    case BLImportStepLookupEntry:
                        [importer performImportStepLookupEntry:item];
                        break;
                    case BLImportStepDownloadBundle:
                        [importer performImportStepDownloadBundle:item];
                        break;
                    case BLImportStepBuildEngine:
                        break;
                    case BLImportStepCreateBundle:
                        break;
                    case BLImportStepOrganize:
                        break;
                    case BLImportStepCreateGame:
                        break;
                    default:
                        return;
                }
            }
            
            if ([item importState] == BLImportItemStatusActive)
                [importer scheduleItemForNextStep:item];
        }
    }
}

#pragma mark - Import Steps
- (void)performImportStepCheckVolume:(BLImportItem *)item
{
    // Make sure that the item points to a mounted disk volume
    IMPORTDLog(@"Volume URL: %@", [item sourceURL]);
    
    [[self progressWindow] setMessageText:@"Checking Volume..."];
    
    NSURL *url = [item URL];
    
    if ([url isDirectory])
    {
        // Split the path
        NSArray *pathComponents = [[url path] componentsSeparatedByString:@"/"];
        if (![(NSString *)[pathComponents objectAtIndex:1] isEqualToString:@"Volumes"] || [pathComponents count] != 3) {
            // Throw the error here
            [self stopImportForItem:item withError:[NSError errorWithDomain:@"BLImportFatalDomain" code:1000 userInfo:nil]];
        }
    }
}

- (void)performImportStepCheckDirectory:(BLImportItem *)item
{
    // Try to identify the game name that will be used to lookup for an entry
    // in the online db
    IMPORTDLog(@"Volume URL: %@", [item sourceURL]);
    
    [[self progressWindow] setMessageText:@"Checking Directory..."];
    
    NSURL *url = [item URL];
    NSString *cvolumeName;
    NSError *error;
    
    [url getResourceValue:&cvolumeName forKey:NSURLVolumeNameKey error:&error];
    [self setVolumeName:cvolumeName];
}

- (void)performImportStepLookupEntry:(BLImportItem *)item
{
    IMPORTDLog(@"Volume URL: %@", [item sourceURL]);
    
    [[self progressWindow] setMessageText:@"Looking up game..."];
    [[self progressWindow] setShowsIndeterminateProgressbar:YES];
    
    self.appCake = [[AppCakeAPI alloc] init];
    [item setImportState:BLImportItemStatusWait];
    [[self appCake] searchDBForGameWithName:[self volumeName] toBlock:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
        if ([mappingResult count] < 1) {
            [[self progressWindow] close];
            
            OEHUDAlert *noResultsAlert = [OEHUDAlert alertWithMessageText:@"No results found on the server! You can either search using a different name, or proceed with a manual import." defaultButton:@"Manual Import" alternateButton:@"Manual Search" otherButton:@"Cancel"];
            /*
            [[noResultsAlert messageTextView] setFrame:NSMakeRect(self.progressWindow.messageTextView.frame.origin.x, 16.0, self.progressWindow.messageTextView.frame.size.width,
                                                                         self.progressWindow.messageTextView.frame.size.height)];
            */
            [noResultsAlert setDefaultButtonAction:@selector(startManualImport:) andTarget:self];
            [noResultsAlert setAlternateButtonAction:@selector(reSearchItem:) andTarget:self];
            [noResultsAlert setOtherButtonAction:@selector(cancelModalWindowAndStop:) andTarget:self];
            
            [noResultsAlert runModal];
        }
        else if ([mappingResult count] == 1) {
            // We found a result.
            [item setImportState:BLImportItemStatusActive];
            [self scheduleItemForNextStep:item];
        }
        else {
            // If the results were more than one, let the user choose
        }
    } failBlock:^(RKObjectRequestOperation *operation, NSError *error) {
        [[self progressWindow] close];
        
        OEHUDAlert *errorAlert = [OEHUDAlert alertWithMessageText:@"Error communicating with the server! Please try again later!" defaultButton:@"OK" alternateButton:@""];
        [errorAlert setDefaultButtonAction:@selector(cancelModalWindowAndStop:) andTarget:self];
        [errorAlert runModal];
    }];
}

- (void)performImportStepDownloadBundle:(BLImportItem *)item {
    FIXME("Stub");
}

- (void)reSearchItem:(id)sender {
    [self cancelModalWindow:sender];
    
    FIXME("Open the new alert in a callback to give the already open alert a chance to close");
    
    OEHUDAlert *manualSearchAlert = [OEHUDAlert manualGameSearchWithVolumeName:[self volumeName]];
    [manualSearchAlert setDefaultButtonAction:@selector(startManualGameSearch:) andTarget:self];
    [manualSearchAlert setAlternateButtonAction:@selector(cancelModalWindowAndStop:) andTarget:self];
    [self setAlertCache:manualSearchAlert];
    
    [manualSearchAlert runModal];
}

- (void)startManualGameSearch:(id)sender {
    [self cancelModalWindow:sender];
    
    [[self progressWindow] open];
    [self setVolumeName:[[self alertCache] stringValue]];
    [[self currentItem] setImportState:BLImportItemStatusActive];
    [[self currentItem] setImportStep:BLImportStepCheckDirectory];
    [self scheduleItemForNextStep:[self currentItem]];
}

- (void)startManualImport:(id)sender {
    [self cancelModalWindow:sender];
    [self fetchListOfEngines];
}

- (void)fetchListOfEngines {
    [[self appCake] listOfAllWineBuildsToBlock:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
        if ([mappingResult count] > 0) {
            [self showSelectionAlertWithItems:mappingResult];
        }
        else {
            OEHUDAlert *errorAlert = [OEHUDAlert alertWithMessageText:@"Oops! No engines were found in the database! Please try again later!" defaultButton:@"OK" alternateButton:@""];
            [errorAlert setDefaultButtonAction:@selector(cancelModalWindowAndStop:) andTarget:self];
            [errorAlert runModal];
        }
    } failBlock:^(RKObjectRequestOperation *operation, NSError *error) {
        OEHUDAlert *errorAlert = [OEHUDAlert alertWithMessageText:@"Error communicating with the server! Please try again later!" defaultButton:@"OK" alternateButton:@""];
        [errorAlert setDefaultButtonAction:@selector(cancelModalWindowAndStop:) andTarget:self];
        [errorAlert runModal];
    }];
}

- (void)showSelectionAlertWithItems:(RKMappingResult *)items {
    // Prepare the NSMutableArray from the objects in the result
    NSMutableArray *engines = [NSMutableArray arrayWithArray:[items array]];
    
    OEHUDAlert *selectionAlert = [OEHUDAlert showManualImportAlertWithVolumeName:[self volumeName] andPopupItems:engines];

    [self setAlertCache:selectionAlert];
    [[self alertCache] setAlternateButtonAction:@selector(closeCachedWindowAndStop:) andTarget:self];
    [[self alertCache] open];
}

- (void)closeWindowAndStop:(id)sender {
    [self stopImportForItem:[self currentItem] withError:nil];
    [[self progressWindow] close];
}

- (void)closeCachedWindow:(id)sender {
    [[self alertCache] close];
}

- (void)closeCachedWindowAndStop:(id)sender {
    [self stopImportForItem:[self currentItem] withError:nil];
    [[self alertCache] close];
}

- (void)cancelModalWindow:(id)sender {
    [NSApp stopModal];
}

- (void)cancelModalWindowAndStop:(id)sender {
    [NSApp stopModal];
    [self stopImportForItem:[self currentItem] withError:nil];
}

- (void)scheduleItemForNextStep:(BLImportItem *)item
{
    IMPORTDLog(@"URL: %@", [item sourceURL]);
    if ([item importState] != BLImportItemStatusWait)
        item.importStep++;
    
    if ([self status] == BLImporterStatusRunning)
    {
        dispatch_async(dispatchQueue, ^{
            importBlock(self, item);
        });
    }
    else
        self.activeImports--;
}

- (void)stopImportForItem:(BLImportItem *)item withError:(NSError *)error
{
    IMPORTDLog(@"URL: %@", [item sourceURL]);
    if ([[error domain] isEqualTo:BLImportErrorDomainResolvable])
        [item setImportState:BLImportItemStatusResolvableError];
    else if (error == nil || [[error domain] isEqualTo:BLImportErrorDomainSuccess])
        [item setImportState:BLImportItemStatusFinished];
    else
        [item setImportState:BLImportItemStatusFatalError];
    
    [item setError:error];
    self.activeImports--;
    
    if (([item importState] == BLImportItemStatusFinished || [item importState] == BLImportItemStatusFatalError || [item importState] == BLImportItemStatusCancelled))
    {
        if ([item completionHandler] != nil)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [item completionHandler]();
            });
        }
        
        if ([item error]) DLog(@"%@", [item error]);
        self.numberOfProcessedItems++;
        
        [self cleanupImportForItem:item];
    }
    
    [self processNextItemIfNeeded];
}

- (void)cleanupImportForItem:(BLImportItem *)item
{
    NSError *error = [item error];
    if (error && [[error domain] isEqualTo:BLImportErrorDomainResolvable])
        return;
    
    if ([item importState] == BLImportItemStatusFinished)
    {
        // TODO: Set item properties, add it in the collection and
        // save it in the database.
    }
    
    [[self queue] removeObjectIdenticalTo:item];
}

#pragma mark - Importing games into collections
- (BOOL)importItemAtPath:(NSString *)path intoCollectionWithID:(NSURL *)collectionID
{
    return [self importItemAtPath:path intoCollectionWithID:collectionID withCompletionHandler:nil];
}

#pragma mark - Importing games into collections with completion handler
- (BOOL)importItemAtPath:(NSString *)path intoCollectionWithID:(NSURL *)collectionID withCompletionHandler:(BLImportItemCompletionBlock)handler
{
    NSURL *url = [NSURL fileURLWithPath:path];
    return [self importItemAtURL:url intoCollectionWithID:collectionID withCompletionHandler:handler];
}

- (BOOL)importItemAtURL:(NSURL *)url intoCollectionWithID:(NSURL *)collectionID withCompletionHandler:(BLImportItemCompletionBlock)handler
{
    id item = [[self queue] firstObjectMatchingBlock:
               ^ BOOL (id item)
               {
                   return [[item URL] isEqualTo:url];
               }];
    
    if (item == nil) {
        BLImportItem *item = [BLImportItem itemWithURL:url andCompletionHandler:handler];
        if (item)
        {
            if (collectionID) [[item importInfo] setObject:collectionID forKey:BLImportInfoCollectionID];
            [[self queue] addObject:item];
            self.totalNumberOfItems++;
            [self setCurrentItem:item];
            [self start];
            return YES;
        }
    }
    
    return NO;
}

#pragma mark - Controlling Import -
- (void)start
{
    IMPORTDLog();
    if ([self status] == BLImporterStatusPaused || [self status] == BLImporterStatusStopped)
    {
        // Show a progress window
        self.progressWindow = [OEHUDAlert showProgressAlertWithMessage:@"Importing game, please wait..." andTitle:@"Importing Game"];
        
        [[self progressWindow] open];
        
        [self setStatus:BLImporterStatusRunning];
        [self processNextItemIfNeeded];
        // Perform selector here
    }
}

@end
