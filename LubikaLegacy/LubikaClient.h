#import <Foundation/Foundation.h>

@class UIImage;

typedef enum {
    LubikaQRTime     = 'H',
    LubikaQRPeriodic = 'P',
    LubikaQRStop     = 'E',
    LubikaQRUser     = 'U'
} LubikaQRType;

@interface LubikaClient : NSObject

+ (LubikaClient *)shared;

@property (nonatomic, copy)   NSString *baseURL;
@property (nonatomic, copy)   NSString *token;
@property (nonatomic, copy)   NSString *refreshToken;
@property (nonatomic, copy)   NSString *iid;
@property (nonatomic, copy)   NSString *cardNumber;
@property (nonatomic, copy)   NSString *verHeader;
@property (nonatomic, readonly, getter=isLoggedIn) BOOL loggedIn;

@property (nonatomic, strong) NSDictionary *user;
@property (nonatomic, strong) UIImage     *photo;

- (NSString *)firstName;
- (NSString *)lastName;
- (NSString *)displayName;
- (NSString *)email;
- (NSString *)balanceText;

- (void)loginWithUsername:(NSString *)username
                 password:(NSString *)password
               completion:(void (^)(NSDictionary *data, NSError *error))completion;

- (void)getUserWithCompletion:(void (^)(NSDictionary *data, NSError *error))completion;

- (void)getPhotoWithCompletion:(void (^)(UIImage *photo, NSError *error))completion;

- (void)getControlQRForType:(LubikaQRType)type
                 completion:(void (^)(id image, NSDictionary *data, NSError *error))completion;

- (NSString *)ensureIid;
- (void)generateIidSmsForPhone:(NSString *)phone
                    completion:(void (^)(NSDictionary *data, NSError *error))completion;
- (void)verifyIidSmsForPhone:(NSString *)phone code:(NSString *)code
                  completion:(void (^)(NSDictionary *data, NSError *error))completion;

- (void)logout;

@end
