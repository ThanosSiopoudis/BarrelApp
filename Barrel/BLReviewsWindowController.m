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

#import "OEDBGame.h"
#import "OEHUDAlert+DefaultAlertsAdditions.h"
#import "BL_GenericAPIResponse.h"
#import "AppCakeAPI.h"

#import "BLReviewsWindowController.h"

@interface BLReviewsWindowController () {
    IBOutlet NSLevelIndicator *starRating;
    IBOutlet OETextField *title;
    IBOutlet OETextField *comment;
}

@property(nonatomic, readwrite) OEDBGame *game;

@end

@implementation BLReviewsWindowController

- (id)initWithWindow:(NSWindow *)window
{
    return [super initWithWindow:window];
}

- (id)initWithGame:(OEDBGame *)game {
    self = [self initWithWindowNibName:[self windowNibName]];
    if (self) {
        [self setGame:game];
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    NSWindow *reviewsWindow = [self window];
    [reviewsWindow setTitle:[NSString stringWithFormat:@"Write a review for %@", [[self game] name]]];
    
    NSColor *windowBackgroundColor = [NSColor colorWithDeviceRed:(82.0/255.0) green:(90.0/255.0) blue:(104.0/255.0) alpha:1.0];
    [reviewsWindow setBackgroundColor:windowBackgroundColor];
}

- (NSString*)windowNibName
{
    return @"Review";
}

#pragma mark Interface Actions
- (IBAction)sendReviewToServer:(id)sender {
    NSError *validationError = [NSError alloc];
    NSMutableDictionary *errorDescription = [NSMutableDictionary dictionary];
    BOOL valid = YES;
    
    // Collect all needed data and validate
    NSInteger rating = [starRating integerValue];
    NSString *titleText = [title stringValue];
    NSString *commentText = [comment stringValue];
    NSInteger userID = [[[NSUserDefaults standardUserDefaults] valueForKey:@"userID"] integerValue];
    NSInteger gameID = [[[self game] apiID] integerValue];
    
    // Validate
    if (rating == 0) {
        [errorDescription setValue:@"Please select a rating greater than zero." forKey:NSLocalizedDescriptionKey];
        valid = NO;
    }
    if ([titleText length] < 1) {
        [errorDescription setValue:@"Please enter a title before submitting your review." forKey:NSLocalizedDescriptionKey];
        valid = NO;
    }
    if (!gameID) {
        [errorDescription setValue:@"This game has not been matched to a database entry. Please, either upload your bundle before rating, or rate a game that exists on the server." forKey:NSLocalizedDescriptionKey];
        valid = NO;
    }
    
    if (!valid) {
        validationError = [NSError errorWithDomain:@"BLWarningDomain" code:100 userInfo:errorDescription];
        OEHUDAlert *alert = [OEHUDAlert alertWithError:validationError];
        [alert runModal];
        return;
    }
    
    // We're ok if we made it this far. Proceed with uploading the data to the server
    AppCakeAPI *apiConnection = [[AppCakeAPI alloc] init];
    [apiConnection uploadReviewForGameID:gameID byUser:userID withTitle:titleText withComment:commentText andRating:rating toBlock:^(RKObjectRequestOperation *requestOperation, RKMappingResult *mappingResult) {
        if ([mappingResult count] > 0) {
            BL_GenericAPIResponse *genericResponse = [mappingResult firstObject];
            if ([genericResponse responseCode] != 200) {
                NSMutableDictionary *errorDescription = [NSMutableDictionary dictionary];
                [errorDescription setValue:[genericResponse description] forKey:NSLocalizedDescriptionKey];
                NSError *codedError = [NSError errorWithDomain:@"BLFatalDomain" code:[genericResponse responseCode] userInfo:errorDescription];
                OEHUDAlert *alert = [OEHUDAlert alertWithError:codedError];
                [alert runModal];
            }
            else {
                [self close];
                OEHUDAlert *success = [OEHUDAlert alertWithMessageText:@"Your review has been submitted. Thank you!" defaultButton:@"OK" alternateButton:@""];
                [success runModal];
            }
        }
        else {
            NSMutableDictionary *errorDescription = [NSMutableDictionary dictionary];
            [errorDescription setValue:@"Could not get a response from the server. Please try again later." forKey:NSLocalizedDescriptionKey];
            NSError *codedError = [NSError errorWithDomain:@"BLFatalDomain" code:404 userInfo:errorDescription];
            OEHUDAlert *alert = [OEHUDAlert alertWithError:codedError];
            [alert runModal];
        }
    } failBlock:^(RKObjectRequestOperation *requestOperation, NSError *responseError) {
        OEHUDAlert *alert = [OEHUDAlert alertWithError:responseError];
        [alert runModal];
    }];
}

- (IBAction)closeReviewWindow:(id)sender {
    [self close];
}
#pragma mark -

@end
