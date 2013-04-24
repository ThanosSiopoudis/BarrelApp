//
//  BLImportItem.h
//  Barrel
//
//  Created by Thanos Siopoudis on 23/04/2013.
//
//

#import <Foundation/Foundation.h>

typedef enum {
    BLImportItemStatusIdle,
    BLImportItemStatusActive,
    BLImportItemStatusResolvableError,
    BLImportItemStatusFatalError,
    BLImportItemStatusFinished,
    BLImportItemStatusCancelled
} BLImportItemState;

typedef enum {
    BLImportStepCheckVolume,
    BLImportStepCheckDirectory,
    BLImportStepLookupEntry,
    BLImportStepBuildEngine,
    BLImportStepCreateBundle,
    BLImportStepOrganize,
    BLImportStepCreateGame,
} BLImportStep;

typedef void (^BLImportItemCompletionBlock)(void);

@interface BLImportItem : NSObject <NSObject, NSCoding>

@property(copy) NSURL                           *URL;
@property(copy) NSURL                           *sourceURL;
@property       BLImportItemState               importState;
@property       BLImportStep                    importStep;
@property       NSMutableDictionary             *importInfo;

@property       NSError                         *error;
@property(copy) BLImportItemCompletionBlock     completionHandler;

+ (id)itemWithURL:(NSURL *)url andCompletionHandler:(BLImportItemCompletionBlock)handler;

@end
