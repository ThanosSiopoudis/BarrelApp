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
#import "OEDBCollection.h"

#import "OELibraryDatabase.h"
#import "NSArray+OEAdditions.h"
#import "NSURL+OELibraryAdditions.h"

#import "OEHUDAlert.h"
#import "OEHUDAlert+DefaultAlertsAdditions.h"

#import "AppCakeAPI.h"
#import "AC_WineBuild.h"
#import "AC_Game.h"

#import "BLFileDownloader.h"
#import "BLArchiver.h"
#import "BLSystemCommand.h"

static const int MaxSimultaneousImports = 1; // imports can't really be simultaneous because access to queue is not ready for multithreadding right now

NSString *const BLOrganizeLibraryKey       = @"organizeLibrary";
NSString *const BLCopyToLibraryKey         = @"copyToLibrary";
NSString *const BLAutomaticallyGetInfoKey  = @"automaticallyGetInfo";

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

@property(readwrite)            NSInteger           status;
@property(readwrite)            NSInteger           activeImports;
@property(readwrite)            NSInteger           numberOfProcessedItems;
@property(readwrite, nonatomic) NSInteger           totalNumberOfItems;
@property(readwrite)            NSMutableArray      *queue;
@property(weak)                 OELibraryDatabase   *database;
@property(readwrite, atomic)    OEHUDAlert          *progressWindow;
@property(readwrite)            NSString            *volumeName;
@property(readwrite)            NSString            *gameName;
@property(readwrite)            NSString            *downloadPath;
@property(readwrite)            AppCakeAPI          *appCake;
@property(readwrite)            BLImportItem        *currentItem;
@property(readwrite, atomic)    OEHUDAlert          *alertCache;
@property(readwrite)            NSString            *scriptPath;
@property(readwrite)            NSString            *engineID;
@property(readwrite)            AC_Game             *serverGame;
@property(readwrite)            NSString            *downloadedRecipePath;
@property(readwrite)            BLFileDownloader    *downloaderCache;
@property(readwrite)            NSString            *execPath;

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
- (IBAction)didSelectGameRecipe:(id)sender;

@end

@implementation BLGameImporter
@synthesize database, delegate;

+ (void)initialize
{
    if (self != [BLGameImporter class]) return;
    [[NSUserDefaults standardUserDefaults] registerDefaults:(@{
                                                             BLOrganizeLibraryKey: @(YES),
                                                             BLCopyToLibraryKey: @(YES),BLAutomaticallyGetInfoKey: @(YES),
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
    // Do tmp path cleanup
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *directory = [[[self database] tempFolderURL] path];
    NSError *error = nil;
    for (NSString *file in [fm contentsOfDirectoryAtPath:directory error:&error]) {
        BOOL success = [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@", directory, file] error:&error];
        if (!success || error) {
            OEHUDAlert *alert = [OEHUDAlert alertWithError:error];
            [alert runModal];
        }
    }
    
    // Determine first and foremost if we have a Genre as everything will fail if we don't
    if ([[item importInfo] valueForKey:BLImportInfoSystemID] == nil) {
        [[self progressWindow] close];
        NSArray *systems = [OEDBSystem allSystems];
        
        OEHUDAlert *chooseGenreAlert = [OEHUDAlert showGenreSelectionAlertWithGenres:systems];
        [chooseGenreAlert runModal];
        
        [[item importInfo] setValue:[[chooseGenreAlert popupButtonSelectedItem] systemIdentifier] forKey:BLImportInfoSystemID];
    }
    
    // That's as far as we go if we're creating an empty or Steam bundle...
    if ([item isEmptyBundle] || [item isSteamBundle]) {
        return;
    }
    
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
    else { // Only accept exetuables
        if (![[[url lastPathComponent] pathExtension] isEqualToString:@"exe"]) {
            // Throw the error here
            [self stopImportForItem:item withError:[NSError errorWithDomain:@"BLImportFatalDomain" code:1000 userInfo:nil]];
        }
    }
}

- (void)performImportStepCheckDirectory:(BLImportItem *)item
{
    // No need for this step if we're creating an empty or Steam bundle
    if ([item isEmptyBundle] || [item isSteamBundle]) {
        return;
    }
    
    // Try to identify the game name that will be used to lookup for an entry
    // in the online db
    IMPORTDLog(@"Volume URL: %@", [item sourceURL]);
    NSURL *url = [item URL];
    NSString *cvolumeName;
    NSError *error;
    
    if ([url isDirectory]) {
        [[self progressWindow] setMessageText:@"Checking Volume..."];
        [url getResourceValue:&cvolumeName forKey:NSURLVolumeNameKey error:&error];
        
        if (error) {
            // Throw the error here
            [self stopImportForItem:item withError:error];
        }
        
        [self setVolumeName:cvolumeName];
    }
    else {
        [[self progressWindow] setMessageText:@"Checking File..."];
        NSString *filename = [url lastPathComponent];
        NSArray *fileParts = [filename componentsSeparatedByString:@"."];
        filename = [fileParts objectAtIndex:0];
        
        [self setVolumeName:filename];
    }
}

- (void)performImportStepLookupEntry:(BLImportItem *)item
{
    IMPORTDLog(@"Volume URL: %@", [item sourceURL]);
    self.appCake = [[AppCakeAPI alloc] init];
    [item setImportState:BLImportItemStatusWait];
    
    // Present the Manual import immediately if empty bundle
    if ([item isEmptyBundle]) {
        [self startManualImport:nil];
        return;
    }
    
    // If this is Steam, prompt the user for a name to search before proceeding
    if ([item isSteamBundle] && [self volumeName] == nil) {
        [self reSearchItem:nil];
        return;
    }
    
    [[self progressWindow] setMessageText:@"Looking up game..."];
    [[self progressWindow] setShowsIndeterminateProgressbar:YES];
    
    [[self appCake] searchDBForGameWithName:[self volumeName] orIdentifier:[self volumeName] toBlock:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
        if ([mappingResult count] < 1) {
            [[self progressWindow] close];
            
            OEHUDAlert *noResultsAlert = [OEHUDAlert alertWithMessageText:@"No results found on the server! You can either search using a different name, or proceed with a manual import." defaultButton:@"Manual Import" alternateButton:@"Manual Search" otherButton:@"Cancel"];
            [noResultsAlert setDefaultButtonAction:@selector(startManualImport:) andTarget:self];
            [noResultsAlert setAlternateButtonAction:@selector(reSearchItem:) andTarget:self];
            [noResultsAlert setOtherButtonAction:@selector(cancelModalWindowAndStop:) andTarget:self];
            
            [noResultsAlert runModal];
        }
        else if ([mappingResult count] == 1) {
            [self getRecipeAndContinue:[mappingResult firstObject] withItem:item];
        }
        else {
            // If the results were more than one, let the user choose
            [[self progressWindow] close];
            NSMutableArray *results = [NSMutableArray arrayWithArray:[mappingResult array]];
            OEHUDAlert *chooseGameAlert = [OEHUDAlert alertWithMessageText:@"Barrel found more than one match on the server. Please select the game that you want to install." defaultButton:@"OK" alternateButton:@"" otherButton:@"Cancel" popupGameItems:results popupButtonLabel:@"Game"];
            [self setAlertCache:chooseGameAlert];
            [[self alertCache] open];
            [[self alertCache] setDefaultButtonAction:@selector(didSelectGameRecipe:) andTarget:self];
            [[self alertCache] setOtherButtonAction:@selector(cancelModalWindowAndStop:) andTarget:self];
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
    
    NSString *path = [[[[self database] databaseFolderURL] URLByAppendingPathComponent:@"tmp"] path];
    // Do we already have the engine in the cache?
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/Engines/%@", [[[self database] cacheFolderURL] path], [[self downloadPath] lastPathComponent]]] && [[NSUserDefaults standardUserDefaults] valueForKey:@"keepLocalCopyOfEngines"]) {
        [self extractArchive:[NSString stringWithFormat:@"%@/Engines/%@", [[[self database] cacheFolderURL] path], [[self downloadPath] lastPathComponent]] toPath:path];
    }
    else {
        OEHUDAlert *downloadAlert = [OEHUDAlert showProgressAlertWithMessage:@"Downloading..." andTitle:@"Download" indeterminate:NO];
        [self setAlertCache:downloadAlert];
        [[self alertCache] open];
        
        // Run the downloader in the main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            BLFileDownloader *fileDownloader = [[BLFileDownloader alloc] initWithProgressBar:[[self alertCache] progressbar] saveToPath:path];
            [self setDownloaderCache:fileDownloader];
            [[self alertCache] setDefaultButtonAction:@selector(cancelDownloadAndStop) andTarget:self];
            [fileDownloader downloadWithNSURLConnectionFromURL:[self downloadPath] withCompletionBlock:^(int result, NSString *resultPath) {
                if (result) {
                    // The bundle has been downloaded, so proceed with extracting it and deleting the archive
                    [[self alertCache] close];
                    [self extractArchive:resultPath toPath:path];
                }
                else {
                    // Something went wrong, abort
                    [[self alertCache] close];
                    OEHUDAlert *errorAlert = [OEHUDAlert alertWithMessageText:@"Error communicating with the server! Please try again later!" defaultButton:@"OK" alternateButton:@""];
                    [errorAlert setDefaultButtonAction:@selector(cancelModalWindowAndStop:) andTarget:self];
                    [errorAlert runModal];
                }
            }];
            [fileDownloader startDownload];
        });
    }
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
    NSString *destinationPath = [[[[self database] databaseFolderURL] URLByAppendingPathComponent:@"tmp"] path];
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
                
                // Add some info in the newly created bundle's plist
                NSMutableDictionary *plist =
                    [NSMutableDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.app/Contents/Info.plist", destinationPath, [self gameName]]];
                [plist setValue:[self volumeName] forKey:@"BLVolumeName"];
                [plist setValue:[self engineID] forKey:@"BLEngineID"];
                
                // If this is a Steam bundle, write it in the plist
                if ([item isSteamBundle])
                    [plist setValue:@"TRUE" forKey:@"BLSteamBundle"];
                
                [plist writeToFile:[NSString stringWithFormat:@"%@/%@.app/Contents/Info.plist", destinationPath, [self gameName]] atomically:YES];
                
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
    // Is this empty? Go away if it is
    if ([item isEmptyBundle] || [item isSteamBundle]) {
        return;
    }
    
    // Run the setup in BarrelApp and wait for the whole process to finish
    NSString *newBundlePath = [[[[self database] databaseFolderURL] URLByAppendingPathComponent:@"tmp"] path];
    NSString *newBarrelApp = [NSString stringWithFormat:@"%@/%@.app", newBundlePath, [self gameName]];
    
    // Find the setup.exe or run the file
    NSURL *url = [item URL];
    NSString *setupEXE;
    
    if ([url isDirectory]) {
        setupEXE = [NSString stringWithFormat:@"%@/setup.exe", [url path]];
    }
    else {
        setupEXE = [url path];
    }
    [self runScript:newBarrelApp withArguments:[NSArray arrayWithObjects:@"--runSetup", setupEXE, nil] shouldWaitForProcess:YES];
}

- (void)performImportStepOrganize:(BLImportItem *)item {
    NSError     *error              = nil;
    NSArray     *genreComponents    = [[[item importInfo] valueForKey:BLImportInfoSystemID] componentsSeparatedByString:@"."];
    NSString    *genre              = [genreComponents lastObject];
    NSString    *newBundlePath      = [[[[self database] databaseFolderURL] URLByAppendingPathComponent:@"tmp"] path];
    NSString    *newBarrelApp       = [NSString stringWithFormat:@"%@/%@.app", newBundlePath, [self gameName]];
    NSBundle    *newBarrelBundle    = [NSBundle bundleWithPath:newBarrelApp];
    NSURL       *url                = [NSURL fileURLWithPath:newBarrelApp];
    NSURL       *newUrl             = [[[self database] gamesFolderURL] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@.app", genre, [self gameName]]];
    
    // Was the installation successful? Check the new bundle for a proper windows executable
    // Only if we're not creating an empty or Steam bundle though
    if (![item isEmptyBundle] && ![item isSteamBundle]) {
        NSMutableDictionary *newBundleInfo = [NSMutableDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/Contents/Info.plist", newBarrelApp]];
        NSString *newWinBinary = [newBundleInfo valueForKey:@"Windows Executable"];
        if ([newWinBinary isEqualToString:@"none.exe"]) {
            // Failed. Halt
            [self stopImportForItem:item withError:error];
            return;
        }
    }
    
    if ([item isSteamBundle]) {
        OEHUDAlert *steamWarning = [OEHUDAlert alertWithMessageText:@"Warning: Steam is about to be installed in the bundle. The process is known to take a while and may look stuck at times, but let it finish through. Login with your account and download the game you want to play when prompted to login. When the installation is finished, exit Steam and also quit from the toolbar icon. If it gets stuck you can safely Force Quit from the Dock." defaultButton:@"I Understand" alternateButton:@""];
        [steamWarning runModal];
    }
    
    // If we have a downloaded recipe, run the required winetricks
    if (([self downloadedRecipePath] != nil && [[self downloadedRecipePath] length] > 0) || [item isSteamBundle]) {
        
        NSMutableDictionary *recipe;
        NSString *winetricksVerbs;
        
        if ([self downloadedRecipePath] != nil && [[self downloadedRecipePath] length] > 0) {
            recipe = [NSMutableDictionary dictionaryWithContentsOfFile:[self downloadedRecipePath]];
            winetricksVerbs = [recipe valueForKey:@"BLWinetricksVerbs"];
            if ([winetricksVerbs length]) {
                winetricksVerbs = [NSString stringWithFormat:@"steam, %@", winetricksVerbs];
            }
            else if ([item isSteamBundle]) {
                winetricksVerbs = @"steam";
            }
        }
        else if ([item isSteamBundle]) {
            winetricksVerbs = @"steam";
        }
        
        if ([winetricksVerbs length]) {
            [item setImportState:BLImportItemStatusWait];
            NSString *winetricksSrc = @"http://winetricks.googlecode.com/svn/trunk/src/winetricks";
            OEHUDAlert *downloadAlert = [OEHUDAlert showProgressAlertWithMessage:@"Downloading Winetricks..." andTitle:@"Download" indeterminate:NO];
            [self setAlertCache:downloadAlert];
            [[self alertCache] open];
            NSString *path = [[[self database] cacheFolderURL] path];
            // Run the downloader in the main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                BLFileDownloader *fileDownloader = [[BLFileDownloader alloc] initWithProgressBar:[[self alertCache] progressbar] saveToPath:path];
                [self setDownloaderCache:fileDownloader];
                [[self alertCache] setDefaultButtonAction:@selector(cancelDownloadAndStop) andTarget:self];
                [fileDownloader downloadWithNSURLConnectionFromURL:winetricksSrc withCompletionBlock:^(int result, NSString *resultPath) {
                    if (result) {
                        // Finally, change the binary rights and move it inside the wrappers binaries folder
                        NSString *command = [NSString stringWithFormat:@"chmod 755 \"%@\"", resultPath];
                        [BLSystemCommand systemCommand:command shouldWaitForProcess:YES];
                        [[self alertCache] close];
                        
                        NSError *fsError = nil;
                        [[NSFileManager defaultManager] moveItemAtPath:resultPath toPath:[NSString stringWithFormat:@"%@/Contents/Frameworks/blwine.bundle/bin/winetricks", newBarrelApp] error:&fsError];
                        
                        OEHUDAlert *winetricksAlert = [OEHUDAlert showProgressAlertWithMessage:@"Installing Winetricks... This may take a while..." andTitle:@"Installing Winetricks" indeterminate:YES];
                        [self setAlertCache:winetricksAlert];
                        [[self alertCache] open];
                        
                        NSString *winetricksFinalCommand = [NSString stringWithFormat:@"%@/BLWineLauncher", [[newBarrelBundle executablePath] stringByDeletingLastPathComponent]];
                        NSMutableArray *args = [NSMutableArray arrayWithObject:@"--runWinetricks"];
                        [args addObjectsFromArray:[winetricksVerbs componentsSeparatedByString:@", "]];
                        
                        dispatch_async(dispatchQueue, ^{
                            [BLSystemCommand runScript:winetricksFinalCommand withArguments:args shouldWaitForProcess:YES runForMain:NO];
                            [[self alertCache] close];
                            
                            [self organiseItemWithGenre:genre URL:url NewURL:newUrl andItem:item];
                            [item setImportState:BLImportItemStatusActive];
                            [self scheduleItemForNextStep:item];
                        });
                    }
                }];
                [fileDownloader startDownload];
            });
        }
        else {
            [self organiseItemWithGenre:genre URL:url NewURL:newUrl andItem:item];
        }
    }
    else {
        [self organiseItemWithGenre:genre URL:url NewURL:newUrl andItem:item];
    }
}

- (void)saveBundleExecutablePath {
    [self setExecPath:[[self alertCache] popupButtonSelectedItem]];
    [NSApp stopModal];
}

- (void) organiseItemWithGenre:(NSString *)genre URL:(NSURL *)url NewURL:(NSURL *)newUrl andItem:(BLImportItem *)item {
    NSError *error = nil;
    
    if ([item isSteamBundle]) {
        // Set the executable to steam
        
        NSMutableDictionary *plist = [[NSMutableDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/Contents/Info.plist", [url path]]];
        [plist setValue:@"drive_c/Program Files/Steam/Steam.exe" forKey:@"Windows Executable"];
        [plist writeToFile:[NSString stringWithFormat:@"%@/Contents/Info.plist", [url path]] atomically:YES];
    }
    
    
    [[NSFileManager defaultManager] createDirectoryAtURL:[[[self database] gamesFolderURL] URLByAppendingPathComponent:genre] withIntermediateDirectories:YES attributes:nil error:&error];
    
    // Move the finished bundle to the library folder
    if (![url isSubpathOfURL:[[[self database] gamesFolderURL] URLByAppendingPathComponent:genre]]) {
        [[NSFileManager defaultManager] moveItemAtURL:url toURL:newUrl error:&error];
    }
    else {
        error = [NSError errorWithDomain:@"BLImportFatalDomain" code:2000 userInfo:nil];
        OEHUDAlert *errorAlert = [OEHUDAlert alertWithMessageText:@"The game already exists in your Database! Import has been halted." defaultButton:@"OK" alternateButton:@""];
        [errorAlert runModal];
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
    OEDBSystem *system = [OEDBSystem systemForPluginIdentifier:[[item importInfo] valueForKey:BLImportInfoSystemID] inDatabase:[self database]];
    
    game = [OEDBGame createGameWithName:[self gameName] andGenre:@"barrel.genre.strategy" andSystem:system andBundlePath:[[item URL] path] inDatabase:[self database]];
    
    // Do we have artwork from the API? If yes, set it
    if ([self serverGame] != nil) {
        if ([[[self serverGame] coverArtURL] length]) {
            [game setBoxImageByURL:[NSURL URLWithString:[[self serverGame] coverArtURL]]];
        }
        [game setAuthorIDInfo:[NSNumber numberWithInteger:[[self serverGame] userID]] andAPIIDInfo:[NSNumber numberWithInteger:[[self serverGame] id]]];
    }
    
    if ([[item importInfo] valueForKey:BLImportInfoCollectionID] != nil) {
        NSArray *collections = [[self database] collections];
        for (id collection in collections) {
            if([collection isMemberOfClass:[OEDBCollection class]]) {
                NSURL *currentURIRep = [[(OEDBCollection *)collection objectID] URIRepresentation];
                NSURL *storedURIRep = [[item importInfo] valueForKey:BLImportInfoCollectionID];
                if ([currentURIRep isEqual:storedURIRep]) {
                    [[collection mutableGames] addObject:game];
                    [[collection managedObjectContext] save:nil];
                }
            }
        }
    }
    
    if (game != nil) {
        [self stopImportForItem:item withError:nil];
    }
}

#pragma mark Perform Helper Methods
- (IBAction)didSelectGameRecipe:(id)sender {
    AC_Game *selectedGame = [[self alertCache] popupButtonSelectedItem];
    [[self alertCache] close];
    [self getRecipeAndContinue:selectedGame withItem:[self currentItem]];
}

- (void)getRecipeAndContinue:(AC_Game *)game withItem:(BLImportItem *)item {
    // We found a result. One result means get it.
    [self setServerGame:game];
    
    // Quickly save the volumename in the database
    // We don't mind if it fails, it's not fatal if it's not able to store it
    [[self appCake] pushIdentifierToServer:[self volumeName] forGameWithID: [NSString stringWithFormat:@"%li", (long)[[self serverGame] id]] toBlock:nil failBlock:nil];
    [[self progressWindow] close];
    
    // Fetch the .plist file
    OEHUDAlert *downloadAlert = [OEHUDAlert showProgressAlertWithMessage:@"Downloading Recipe..." andTitle:@"Download" indeterminate:NO];
    [self setAlertCache:downloadAlert];
    [[self alertCache] open];
    NSString *path = [[[self database] tempFolderURL] path];
    // Run the downloader in the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        BLFileDownloader *fileDownloader = [[BLFileDownloader alloc] initWithProgressBar:[[self alertCache] progressbar] saveToPath:path];
        [self setDownloaderCache:fileDownloader];
        [[self alertCache] setDefaultButtonAction:@selector(cancelDownloadAndStop) andTarget:self];
        [fileDownloader downloadWithNSURLConnectionFromURL:[[self serverGame] recipeURL] withCompletionBlock:^(int result, NSString *resultPath) {
            [[self alertCache] close];
            if (result) {
                [self setDownloadedRecipePath:resultPath];
                [self setDownloadPath:[[self serverGame] engineURL]];
                [self setGameName:[[self serverGame] name]];
                [self setEngineID:[NSString stringWithFormat:@"%li",(long)[[self serverGame] wineBuildID]]];
                
                [item setImportState:BLImportItemStatusActive];
                [self scheduleItemForNextStep:item];
            }
            else {
                // Something went wrong, abort
                [[self alertCache] close];
                OEHUDAlert *errorAlert = [OEHUDAlert alertWithMessageText:@"Error communicating with the server! Please try again later!" defaultButton:@"OK" alternateButton:@""];
                [errorAlert setDefaultButtonAction:@selector(cancelModalWindowAndStop:) andTarget:self];
                [errorAlert runModal];
            }
        }];
        [fileDownloader startDownload];
    });
}

- (NSMutableArray *)searchFolderForExecutables:(NSString *)folder {
    NSMutableArray *results = [[NSMutableArray alloc] init];
    
    NSDirectoryEnumerator *direnum = [[NSFileManager defaultManager] enumeratorAtURL:[NSURL URLWithString:[folder stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLNameKey, NSURLIsDirectoryKey, nil] options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:nil];
    
    NSNumber *isDirectory = nil;
    NSError *error;
    
    for (NSURL *url in direnum) {
        if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            // ERROR
        }
        else if (![isDirectory boolValue]) {
            // It's a file. Add it to the array if it's an .exe
            if ([[url pathExtension] isEqualToString:@"exe"]) {
                [results addObject:[url path]];
            }
        }
    }
    
    return results;
}

- (void)cancelDownloadAndStop {
    [[self alertCache] close];
    [[self downloaderCache] cancelDownload];
    [self stopImportForItem:[self currentItem] withError:nil];
}

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
                // Does the user want a local engine cache? If yes don't delete, but move into cache folder
                if ([[NSUserDefaults standardUserDefaults] valueForKey:@"keepLocalCopyOfEngines"]) {
                    if (![[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/Engines", [[[self database] cacheFolderURL] path]]]) {
                        [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@/Engines", [[[self database] cacheFolderURL] path]] withIntermediateDirectories:YES attributes:nil error:nil];
                        [[NSFileManager defaultManager] moveItemAtPath:archivePath toPath:[NSString stringWithFormat:@"%@/Engines/%@", [[[self database] cacheFolderURL] path], [archivePath lastPathComponent]] error:nil];
                    }
                }
                else {
                    BOOL deleteSuccess = [[NSFileManager defaultManager] removeItemAtPath:archivePath error:nil];
                    [[self alertCache] close];
                    if (!deleteSuccess) {
                        // Non-Fatal error
                        OEHUDAlert *errorAlert = [OEHUDAlert alertWithMessageText:@"Error deleting downloaded archive! Please remove manually." defaultButton:@"OK" alternateButton:@""];
                        [errorAlert runModal];
                    }

                }
                [[self currentItem] setImportState:BLImportItemStatusActive];
                [self scheduleItemForNextStep:[self currentItem]];
            }
        }];
    });
}

- (void)reSearchItem:(id)sender {
    if (sender)
        [self cancelModalWindow:sender];
    FIXME("Open the new alert in a callback to give the already open alert a chance to close");
    
    OEHUDAlert *manualSearchAlert = [OEHUDAlert manualGameSearchWithVolumeName:([self volumeName] !=nil ? [self volumeName] : @"")];
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
    // [self scheduleItemForNextStep:[self currentItem]];
}

- (void)startManualImport:(id)sender {
    [self cancelModalWindow:sender];
    [self fetchListOfEngines];
}

- (void)fetchListOfEngines {
    [[self progressWindow] setMessageText:@"Fetching list of engines..."];
    [[self progressWindow] open];
    [[self appCake] listOfAllWineBuildsToBlock:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
        [[self progressWindow] close];
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
    if (![self volumeName] || [[self volumeName] length] < 1) {
        [self setVolumeName:@"Empty Bundle"];
    }
    
    OEHUDAlert *selectionAlert = [OEHUDAlert showManualImportAlertWithVolumeName:[self volumeName] andPopupItems:engines];

    [self setAlertCache:selectionAlert];
    [[self alertCache] open];
    [[self alertCache] setDefaultButtonAction:@selector(setBundleToDownloadWithGameName:) andTarget:self];
    [[self alertCache] setAlternateButtonAction:@selector(closeCachedWindowAndStop:) andTarget:self];
}

- (void)setBundleToDownloadWithGameName:(id)sender {
    [self setGameName:[[self alertCache] stringValue]];
    AC_WineBuild *build = [[self alertCache] popupButtonSelectedItem];
    [self setDownloadPath:[NSString stringWithFormat:@"%@%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"BLApiServerURL"], [build archivePath]]];
    [self setEngineID:[NSString stringWithFormat:@"%li", (long)[build id]]];
    
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
        // Cleanup temporary directory
        NSArray *tmpContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/tmp", [[[self database] databaseFolderURL] path]] error:nil];
        for (NSString *tmpitem in tmpContents) {
            [[NSFileManager defaultManager] removeItemAtPath:tmpitem error:nil];
        }
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

- (BOOL)importItemsAtPaths:(NSArray *)paths {
    return [self importItemsAtPaths:paths intoCollectionWithID:nil withSystem:nil];
}

- (BOOL)importItemsAtPaths:(NSArray *)paths intoCollectionWithID:(NSURL *)collectionID withSystem:(NSString *)systemID {
    BOOL result = NO;
    for (NSString *importPath in paths) {
        NSURL *url = [NSURL fileURLWithPath:importPath];
        result = [self importItemAtURL:url intoCollectionWithID:collectionID withSystem:systemID withCompletionHandler:nil];
    }
    
    return result;
}

- (BOOL)importItemsAtURLs:(NSArray *)URLs {
    return [self importItemsAtURLs:URLs intoCollectionWithID:nil];
}

- (BOOL)importItemsAtURLs:(NSArray *)URLs intoCollectionWithID:(NSURL *)collectionID {
    BOOL result = NO;
    for (NSURL *importURL in URLs) {
        result = [self importItemAtURL:importURL intoCollectionWithID:collectionID withSystem:nil withCompletionHandler:nil];
    }
    
    return result;
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

#pragma mark - Importing an empty bundle into collections
- (BOOL)importEmptyBundleIntoCollectionWithID:(NSURL *)collectionID {
    return [self importEmptyBundleIntoCollectionWithID:collectionID withSystem:nil];
}

- (BOOL)importSteamBundleIntoCollectionWithID:(NSURL *)collectionID {
    return [self importSteamBundleIntoCollectionWithID:collectionID withSystem:nil];
}

- (BOOL)importSteamBundleIntoCollectionWithID:(NSURL *)collectionID withSystem:(NSString *)systemID {
    return [self importSteamBundleIntoCollectionWithID:collectionID withSystem:systemID withCompletionHandler:nil];
}

- (BOOL)importEmptyBundleIntoCollectionWithID:(NSURL *)collectionID withSystem:(NSString *)systemID {
    return [self importEmptyBundleIntoCollectionWithID:collectionID withSystem:systemID withCompletionHandler:nil];
}

#pragma mark - Importing an empty bundle into collections with completion handler
- (BOOL)importSteamBundleIntoCollectionWithID:(NSURL *)collectionID withSystem:(NSString *)systemID withCompletionHandler:(BLImportItemCompletionBlock)handler {
    BLImportItem *item = [BLImportItem itemWithSteamBundleAndCompletionHandler:handler];
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
    
    return NO;
}

- (BOOL)importEmptyBundleIntoCollectionWithID:(NSURL *)collectionID withSystem:(NSString *)systemID withCompletionHandler:(BLImportItemCompletionBlock)handler {
    
    BLImportItem *item = [BLImportItem itemWithEmptyBundleAndCompletionHandler:handler];
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
