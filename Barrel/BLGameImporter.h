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

#import <Foundation/Foundation.h>
#import "OEImportItem.h"

#ifdef DEBUG_IMPORT
#define IMPORTDLog DLog
#else
#define IMPORTDLog(format, ...) do {} while (0)
#endif

#pragma mark User Default Keys -
extern NSString *const OEOrganizeLibraryKey;
extern NSString *const OECopyToLibraryKey;
extern NSString *const OEAutomaticallyGetInfoKey;

#pragma mark Error Codes -
extern NSString *const OEImportErrorDomainFatal;
extern NSString *const OEImportErrorDomainResolvable;
extern NSString *const OEImportErrorDomainSuccess;

typedef enum : NSInteger {
    BLImportErrorCodeAlreadyInDatabase  = -1,
    BLImportErrorCodeNoEngine           = 2,
    BLImportErrorCodeInvalidFile        = 3,
    BLImportErrorCodeAdditionalFiles    = 5
} BLImportErrorCode;

#pragma mark - Importer Status
typedef enum : NSInteger {
    BLImporterStatusStopped  = 1,
    BLImporterStatusRunning  = 2,
    BLImporterStatusPausing  = 3,
    BLImporterStatusPaused   = 4,
    BLImporterStatusStopping = 5,
} BLImporterStatus;

@class OELibraryDatabase;
@protocol BLGameImporterDelegate;

@interface BLGameImporter : NSObject

- (id)initWithDatabase:(OELibraryDatabase *)aDatabase;

@property(weak, readonly) OELibraryDatabase *database;
@property(strong) id<BLGameImporterDelegate> delegate;

@property(readonly) NSInteger status;

#pragma mark - Importing Game into collections -
- (BOOL)importItemAtPath:(NSString *)path intoCollectionWithID:(NSURL *)collectionID;

#pragma mark - Importing Game into collections with completion handler
- (BOOL)importItemAtPath:(NSString *)path intoCollectionWithID:(NSURL *)collectionID withCompletionHandler:(OEImportItemCompletionBlock)handler;
- (BOOL)importItemAtURL:(NSURL *)url intoCollectionWithID:(NSURL *)collectionID withCompletionHandler:(OEImportItemCompletionBlock)handler;

@end
