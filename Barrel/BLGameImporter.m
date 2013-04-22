//
//  BLGameImporter.m
//  Barrel
//
//  Created by Athanasios Siopoudis on 22/04/2013.
//
//

#import "BLGameImporter.h"

static const int MaxSimultaneousImports = 1; // imports can't really be simultaneous because access to queue is not ready for multithreadding right now

@interface BLGameImporter ()
{
    dispatch_queue_t dispatchQueue;
}

@property(readwrite)            NSInteger          status;
@property(weak)                 OELibraryDatabase *database;

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
        
        dispatchQueue = dispatch_queue_create("com.appcake.importqueue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_t priority = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
        dispatch_set_target_queue(dispatchQueue, priority);
        [self setStatus:BLImporterStatusStopped];
    }
    return self;
}

- (void)dealloc
{
    dispatch_release(dispatchQueue);
}

#pragma mark - Importing games into collections
- (BOOL)importItemAtPath:(NSString *)path intoCollectionWithID:(NSURL *)collectionID
{
    return [self importItemAtPath:path intoCollectionWithID:collectionID withCompletionHandler:nil];
}

#pragma mark - Importing games into collections with completion handler
- (BOOL)importItemAtPath:(NSString *)path intoCollectionWithID:(NSURL *)collectionID withCompletionHandler:(OEImportItemCompletionBlock)handler
{
    NSURL *url = [NSURL fileURLWithPath:path];
    return [self importItemAtURL:url intoCollectionWithID:collectionID withCompletionHandler:handler];
}

- (BOOL)importItemAtURL:(NSURL *)url intoCollectionWithID:(NSURL *)collectionID withCompletionHandler:(OEImportItemCompletionBlock)handler
{
    
}

@end
