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

#import "OELibraryDatabase.h"
#import "NSArray+OEAdditions.h"
#import "NSURL+OELibraryAdditions.h"

#import "OEHUDAlert.h"
#import "OEHUDAlert+DefaultAlertsAdditions.h"

#import "AppCakeAPI.h"
#import "AC_WineBuild.h"
#import "BLFileDownloader.h"
#import "BLArchiver.h"

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
@property(readwrite, atomic)    OEHUDAlert        *progressWindow;
@property(readwrite)            NSString          *volumeName;
@property(readwrite)            NSString          *gameName;
@property(readwrite)            NSString          *downloadPath;
@property(readwrite)            AppCakeAPI        *appCake;
@property(readwrite)            BLImportItem      *currentItem;
@property(readwrite, atomic)    OEHUDAlert        *alertCache;
@property(readwrite)            NSString          *scriptPath;

- (void)processNextItemIfNeeded;

#pragma mark - Import Steps
- (void)performImportStepCheckVolume:(BLImportItem *)item;
- (void)performImportStepCheckDirectory:(BLImportItem *)item;
- (void)performImportStepLookupEntry:(BLImportItem *)item;
- (void)performImportStepDownloadBundle:(BLImportItem *)item;
- (void)performImportStepBuildEngine:(BLImportItem *)item;
- (void)performImportStepCreateBundle:(BLImportItem *)item;
- (void)performImportStepOrganize:(BLImportItem *)item;
- (void)performImportStepCreateGame:(BLImportItem *)item;

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
                        [importer performImportStepBuildEngine:item];
                        break;
                    case BLImportStepCreateBundle:
                        [importer performImportStepCreateBundle:item];
                        break;
                    case BLImportStepOrganize:
                        [importer performImportStepOrganize:item];
                        break;
                    case BLImportStepCreateGame:
                        [importer performImportStepCreateGame:item];
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
    [item setImportState:BLImportItemStatusWait];
    OEHUDAlert *downloadAlert = [OEHUDAlert showProgressAlertWithMessage:@"Downloading..." andTitle:@"Download" indeterminate:NO];
    [self setAlertCache:downloadAlert];
    [[self alertCache] open];
    NSString *path = [[[[self database] gamesFolderURL] URLByAppendingPathComponent:@"Barrel/tmp"] path];
    
    // Run the downloader in the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        BLFileDownloader *fileDownloader = [[BLFileDownloader alloc] initWithProgressBar:[[self alertCache] progressbar] saveToPath:path];
        [fileDownloader downloadWithNSURLConnectionFromURL:[self downloadPath] withCompletionBlock:^(int result, NSString *resultPath) {
            if (result) {
                // The bundle has been downloaded, so proceed with extracting it and deleting the archive
                [[self alertCache] close];
                [self extractArchive:resultPath toPath:path];
            }
        }];
        [fileDownloader startDownload];
    });
}

- (void)performImportStepBuildEngine:(BLImportItem *)item {
    [item setImportState:BLImportItemStatusWait];
    dispatch_async(dispatch_get_main_queue(), ^{
        OEHUDAlert *preparingAlert = [OEHUDAlert showProgressAlertWithMessage:@"Preparing bundle..." andTitle:@"Preparing" indeterminate:YES];
        [self setAlertCache:preparingAlert];
        [[self alertCache] open];
    });
    
    // Copy the empty .app bundle to the tmp directory
    NSString *sourcePath = [[NSBundle mainBundle] pathForResource:@"BarrelApp" ofType:@"app"];
    NSString *destinationPath = [[[[self database] gamesFolderURL] URLByAppendingPathComponent:@"Barrel/tmp"] path];
    [[NSFileManager defaultManager] copyItemAtPath:sourcePath toPath:[NSString stringWithFormat:@"%@/%@.app", destinationPath, [self gameName]] error:nil];
    
    // Copy the blwine.bundle inside the new application bundle
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@/%@.app/Contents/Frameworks", destinationPath, [self gameName]]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    [[NSFileManager defaultManager] copyItemAtPath:[NSString stringWithFormat:@"%@/blwine.bundle", destinationPath] toPath:[NSString stringWithFormat:@"%@/%@.app/Contents/Frameworks/blwine.bundle", destinationPath, [self gameName]] error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/blwine.bundle", destinationPath] error:nil];
    
    // Finally, extract the libraries inside the frameworks folder
    BLArchiver *archiver = [[BLArchiver alloc] initWithArchiveAtPath:[NSString stringWithFormat:@"%@/libraries.zip", destinationPath] andProgressBar:[[self alertCache] progressbar]];
    [[self alertCache] setShowsIndeterminateProgressbar:NO];
    [[self alertCache] setShowsProgressbar:YES];
    [[self alertCache] setMessageText:@"Extracting libraries..."];
    dispatch_async(dispatchQueue, ^{
        [archiver startExtractingToPath:[NSString stringWithFormat:@"%@/%@.app/Contents/Frameworks", destinationPath, [self gameName]] callbackBlock:^(int result) {
            if (result) {
                // Bundle is ready, remove the archive
                BOOL deleteSuccess = [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/libraries.zip", destinationPath] error:nil];
                
                if (!deleteSuccess) {
                    // Non-Fatal error
                    OEHUDAlert *errorAlert = [OEHUDAlert alertWithMessageText:@"Error deleting downloaded archive! Please remove manually." defaultButton:@"OK" alternateButton:@""];
                    [errorAlert runModal];
                }
                [[self alertCache] setShowsProgressbar: NO];
                [[self alertCache] setShowsIndeterminateProgressbar:YES];
                [[self alertCache] setMessageText:@"Initializing Wine Prefix..."];
                [self runScript:[NSString stringWithFormat:@"%@/%@.app", destinationPath, [self gameName]] withArguments:[NSArray arrayWithObjects:@"--exec", @"initPrefix", nil] shouldWaitForProcess:YES];
                [[self alertCache] close];
                [item setImportState:BLImportItemStatusActive];
                [self scheduleItemForNextStep:item];
            }
        }];
    });
}

- (void)performImportStepCreateBundle:(BLImportItem *)item {
    // Run the setup in BarrelApp and wait for the whole process to finish
    NSString *newBundlePath = [[[[self database] gamesFolderURL] URLByAppendingPathComponent:@"Barrel/tmp"] path];
    NSString *newBarrelApp = [NSString stringWithFormat:@"%@/%@.app", newBundlePath, [self gameName]];
    
    // Find the setup.exe
    NSURL *url = [item URL];
    NSString *setupEXE = [NSString stringWithFormat:@"%@/setup.exe", [url path]];
    [self runScript:newBarrelApp withArguments:[NSArray arrayWithObjects:@"--runSetup", setupEXE, nil] shouldWaitForProcess:YES];
    
    // FIXME: Check here if the installer failed
}

- (void)performImportStepOrganize:(BLImportItem *)item {
    NSError     *error          = nil;
    NSString    *newBundlePath  = [[[[self database] gamesFolderURL] URLByAppendingPathComponent:@"Barrel/tmp"] path];
    NSString    *newBarrelApp   = [NSString stringWithFormat:@"%@/%@.app", newBundlePath, [self gameName]];
    NSURL       *url            = [NSURL fileURLWithPath:newBarrelApp];
    NSURL       *newUrl         = [[[self database] gamesFolderURL] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.app", [self gameName]]]; // FIXME: Organize the games in their own genre's folder instead of the generic games folder.
    
    // Copy the finished bundle to the library folder
    if (![url isSubpathOfURL:[[self database] gamesFolderURL]]) {
        [[NSFileManager defaultManager] moveItemAtURL:url toURL:newUrl error:&error];
    }
    
    if (error != nil) {
        [self stopImportForItem:item withError:error];
        return;
    }
    
    [item setURL:newUrl];
}

- (void)performImportStepCreateGame:(BLImportItem *)item {
    OEDBGame *game = nil;
    
    // Determine the "System" (Should be renamed to Genre in the future)
    OEDBSystem *system = [OEDBSystem systemForPluginIdentifier:[[item importInfo] valueForKey:OEImportInfoSystemID] inDatabase:[self database]];
    
    game = [OEDBGame createGameWithName:[self gameName] andGenre:@"barrel.genre.strategy" andSystem:system andBundlePath:[[item URL] path] inDatabase:[self database]];
    
    if (game != nil) {
        [self stopImportForItem:item withError:nil];
    }
}

#pragma mark Perform Helper Methods
- (void)runScript:(NSString*)scriptName withArguments:(NSArray *)arguments shouldWaitForProcess:(BOOL)waitForProcess
{
    NSTask *task;
    task = [[NSTask alloc] init];
    
    NSBundle *barrelAppBundle = [NSBundle bundleWithPath:scriptName];
    NSArray *argumentsArray;
    [task setLaunchPath: [barrelAppBundle executablePath]];
    argumentsArray = arguments;
    [task setArguments: argumentsArray];
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];
    
    if (waitForProcess) {
        NSData *data;
        data = [file readDataToEndOfFile];
        
        NSString *string;
        string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    }
}

- (void)extractArchive:(NSString *)archivePath toPath:(NSString *)targetPath {
    [self setAlertCache:[OEHUDAlert showProgressAlertWithMessage:@"Extracting archive..." andTitle:@"Extracting..." indeterminate:NO]];
    [[self alertCache] open];
    BLArchiver *archiver = [[BLArchiver alloc] initWithArchiveAtPath:archivePath andProgressBar:[[self alertCache] progressbar]];
    dispatch_async(dispatchQueue, ^{
        [archiver startExtractingToPath:targetPath callbackBlock:^(int result){
            // Delete the archive if the extraction was successful
            if (result) {
                BOOL deleteSuccess = [[NSFileManager defaultManager] removeItemAtPath:archivePath error:nil];
                [[self alertCache] close];
                if (!deleteSuccess) {
                    // Non-Fatal error
                    OEHUDAlert *errorAlert = [OEHUDAlert alertWithMessageText:@"Error deleting downloaded archive! Please remove manually." defaultButton:@"OK" alternateButton:@""];
                    [errorAlert runModal];
                }
                [[self currentItem] setImportState:BLImportItemStatusActive];
                [self scheduleItemForNextStep:[self currentItem]];
            }
        }];
    });
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
    [[self alertCache] open];
    [[self alertCache] setDefaultButtonAction:@selector(setBundleToDownloadWithGameName:) andTarget:self];
    [[self alertCache] setAlternateButtonAction:@selector(closeCachedWindowAndStop:) andTarget:self];
}

- (void)setBundleToDownloadWithGameName:(id)sender {
    [self setGameName:[[self alertCache] stringValue]];
    AC_WineBuild *build = [[self alertCache] popupButtonSelectedItem];
    [self setDownloadPath:[NSString stringWithFormat:@"http://api.appcake.co.uk%@", [build archivePath]]];
    
    // Close the alert and proceed
    [[self alertCache] close];
    [[self currentItem] setImportState:BLImportItemStatusActive];
    [self scheduleItemForNextStep:[self currentItem]];
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
    return [self importItemAtPath:path intoCollectionWithID:collectionID withSystem:nil withCompletionHandler:nil];
}

- (BOOL)importItemAtPath:(NSString *)path intoCollectionWithID:(NSURL *)collectionID withSystem:(NSString *)systemID {
    return [self importItemAtPath:path intoCollectionWithID:collectionID withSystem:systemID withCompletionHandler:nil];
}

#pragma mark - Importing games into collections with completion handler
- (BOOL)importItemAtPath:(NSString *)path intoCollectionWithID:(NSURL *)collectionID withSystem:(NSString *)systemID withCompletionHandler:(BLImportItemCompletionBlock)handler
{
    NSURL *url = [NSURL fileURLWithPath:path];
    return [self importItemAtURL:url intoCollectionWithID:collectionID withSystem:systemID withCompletionHandler:handler];
}

- (BOOL)importItemAtURL:(NSURL *)url intoCollectionWithID:(NSURL *)collectionID withSystem:(NSString *)systemID withCompletionHandler:(BLImportItemCompletionBlock)handler
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
            if (systemID) [[item importInfo] setObject:systemID forKey:BLImportInfoSystemID];
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
        self.progressWindow = [OEHUDAlert showProgressAlertWithMessage:@"Importing game, please wait..." andTitle:@"Importing Game" indeterminate:YES];
        
        [[self progressWindow] open];
        
        [self setStatus:BLImporterStatusRunning];
        [self processNextItemIfNeeded];
        // Perform selector here
    }
}

@end
