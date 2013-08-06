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
#import <CommonCrypto/CommonDigest.h>

#import "AppCakeAPI.h"
#import "BLPrefUserController.h"
#import "OETextField.h"
#import "OEButton.h"

#import "OEHUDAlert+DefaultAlertsAdditions.h"
#import "AC_User.h"

NSString *const BLUserID        = @"userID";
NSString *const BLUserStatus    = @"userStatus";
NSString *const BLUsername      = @"username";
NSString *const BLPassword      = @"password";
NSString *const BLEmail         = @"email";

@interface BLPrefUserController () {
    IBOutlet OETextField *usernameField, *emailField;
    IBOutlet NSSecureTextField *pwdField;
    IBOutlet OEButton *registrationButton;
    IBOutlet OEButton *loginButton;
}

- (IBAction)didSelectLoginButton:(id)sender;
- (IBAction)didSelectRegisterButton:(id)sender;

@end

@implementation BLPrefUserController

- (void)awakeFromNib {
    // hide focus ring
    [usernameField setFocusRingType:NSFocusRingTypeNone];
    [pwdField setFocusRingType:NSFocusRingTypeNone];
    [emailField setFocusRingType:NSFocusRingTypeNone];
    
    // Check if we're logged in, and set the buttons accordingly if we are
    if ([[[NSUserDefaults standardUserDefaults] valueForKey:BLUserID] boolValue]) {
        // Hide the registration button
        [registrationButton setHidden:YES];
        [loginButton setTitle:@"Log out"];
    }
}

#pragma mark -
#pragma mark OEPreferencePane Protocol

- (NSImage *)icon
{
    return [NSImage imageNamed:@"user_tab_icon"];
}

- (NSString *)title
{
    return @"User Account";
}

- (NSString *)localizedTitle
{
    return NSLocalizedString([self title], "");
}

- (NSSize)viewSize
{
    return NSMakeSize(423, 178);
}

#pragma mark -
#pragma mark Interface Actions
- (IBAction)didSelectLoginButton:(id)sender {
    AppCakeAPI *apiConnection = [[AppCakeAPI alloc] init];
    
    // Generate an SHA-1 Digest for the password
    // It's OK that we don't take endianess into account, as this is a x86_64 only application
    // ARM and PowerPC are not (and should not be) supported
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    NSData *pwdBytes = [[pwdField stringValue] dataUsingEncoding:NSUTF8StringEncoding];
    CC_SHA1([pwdBytes bytes], [pwdBytes length], digest);
    NSString *pwdDigest = [NSString stringWithFormat:@"%s", digest];
    
    [apiConnection loginUserWithUsername:[usernameField stringValue] toBlock:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResults) {
        if ([mappingResults count] > 0) {
            AC_User *user = [mappingResults firstObject];
            if ([[user password] isEqualToString:pwdDigest]) {
                // Success! Store the user ID and set a flag to indicate the user is logged in until we quit the app
                // The app should then automatically try to log in next time it is required
                [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:[user userID]] forKey:BLUserID];
                [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:YES] forKey:BLUserStatus];
                
                // Save the form data
                [[NSUserDefaults standardUserDefaults] setValue:[usernameField stringValue] forKey:BLUsername];
                [[NSUserDefaults standardUserDefaults] setValue:[pwdField stringValue] forKey:BLPassword];
                [[NSUserDefaults standardUserDefaults] setValue:[emailField stringValue] forKey:BLEmail];
                
                // Hide the registration button
                [registrationButton setHidden:YES];
                [loginButton setTitle:@"Log out"];
            }
        }
    } failBlock:^(RKObjectRequestOperation *operation, NSError *error) {
        OEHUDAlert *alert = [OEHUDAlert alertWithError:error];
        [alert runModal];
    }];
}

- (IBAction)didSelectRegisterButton:(id)sender {
    AppCakeAPI *apiConnection = [[AppCakeAPI alloc] init];
    
    // Generate an SHA-1 Digest for the password
    // It's OK that we don't take endianess into account, as this is a x86_64 only application
    // ARM and PowerPC are not (and should not be) supported
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    NSData *pwdBytes = [[pwdField stringValue] dataUsingEncoding:NSUTF8StringEncoding];
    CC_SHA1([pwdBytes bytes], [pwdBytes length], digest);
    
    [apiConnection registerUserWithUsername:[usernameField stringValue] password:[NSString stringWithFormat:@"%s", digest] email:[emailField stringValue] toBlock:^(RKObjectRequestOperation *operation, RKMappingResult *mappingResult) {
        [[NSUserDefaults standardUserDefaults] setValue:[usernameField stringValue] forKey:BLUsername];
        [[NSUserDefaults standardUserDefaults] setValue:[pwdField stringValue] forKey:BLPassword];
        [[NSUserDefaults standardUserDefaults] setValue:[emailField stringValue] forKey:BLEmail];
        
        OEHUDAlert *alert = [OEHUDAlert alertWithMessageText:@"Registration was successful. Please log in now." defaultButton:@"OK" alternateButton:@""];
        [alert runModal];
    } failBlock:^(RKObjectRequestOperation *operation, NSError *error) {
        OEHUDAlert *alert = [OEHUDAlert alertWithError:error];
        [alert runModal];
    }];
}

@end
