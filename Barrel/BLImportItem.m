//
//  BLImportItem.m
//  Barrel
//
//  Created by Thanos Siopoudis on 23/04/2013.
//
//

#import "BLImportItem.h"
#import "NSURL+OELibraryAdditions.h"
#import "BLGameImporter.h"

@implementation BLImportItem

+ (id)itemWithURL:(NSURL *)url andCompletionHandler:(BLImportItemCompletionBlock)handler
{
    id item = nil;
    
    item = [[BLImportItem alloc] init];
    
    [item setURL:url];
    [item setSourceURL:url];
    [item setCompletionHandler:handler];
    [item setImportState:BLImportItemStatusIdle];
    [item setImportInfo:[NSMutableDictionary dictionaryWithCapacity:5]];
    
    return item;
}

- (id)initWithCoder:(NSCoder *)decoder
{
    self = [self init];
    if (self)
    {
        [self setURL:[decoder decodeObjectForKey:@"URL"]];
        [self setSourceURL:[decoder decodeObjectForKey:@"sourceURL"]];
        [self setImportState:BLImportItemStatusIdle];
        [self setImportInfo:[decoder decodeObjectForKey:@"importInfo"]];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:[self URL] forKey:@"URL"];
    [encoder encodeObject:[self sourceURL] forKey:@"sourceURL"];
    [encoder encodeObject:[self importInfo] forKey:@"importInfo"];
}

@end
