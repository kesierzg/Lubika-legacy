#import "LubikaClient.h"
#import <UIKit/UIKit.h>

static NSString * const kDefaultBase = @"https://applubika.zdtm.lublin.eu/api/";

//debug
static void LubikaLog(NSString *fmt, ...) {
    va_list ap; va_start(ap, fmt);
    NSString *line = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);
    NSString *stamped = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], line];
    NSString *path = @"/tmp/lubika_net.log";
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) { [stamped writeToFile:path atomically:NO
                           encoding:NSUTF8StringEncoding error:NULL]; return; }
    [fh seekToEndOfFile];
    [fh writeData:[stamped dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];
}

@interface LubikaClient ()
@property (nonatomic, copy) NSString *expirationDateTime;
@end

@implementation LubikaClient

+ (LubikaClient *)shared {
    static LubikaClient *s; static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[LubikaClient alloc] init]; });
    return s;
}

- (id)init {
    if ((self = [super init])) {
        _baseURL = [kDefaultBase copy];
        // The backend parses `ver` positionally and rejects anything it can't read
        // as "outdated app version". The real header has SIX ';'-separated fields:
        //   Android;<os release>;<sdk int>;<Build.DISPLAY>;lubika;<appVersion>
        // (from eu.lublin.ztm.lubika HttpHeadersInterceptor, v2.2.1 / versionCode 229).
        // Our earlier iOS string had only five fields, so the version slot was empty.
        // Mirror the Android shape exactly so <appVersion> lands in the right slot.
        _verHeader = [@"Android;13;33;TQ3A.230805.001;lubika;2.2.1" copy];
        NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
        _token        = [[u stringForKey:@"lubika.token"] copy];
        _refreshToken = [[u stringForKey:@"lubika.refresh"] copy];
        _iid          = [[u stringForKey:@"lubika.iid"] copy];
        _cardNumber   = [[u stringForKey:@"lubika.card"] copy];
        _expirationDateTime = [[u stringForKey:@"lubika.exp"] copy];
        // The backend requires the `iid` header on EVERY request, including login
        // (Android generates it at splash, before any API call). Generate+persist a
        // stable UUID now so login and all later calls carry it. Binding to the
        // account still happens later via the SMS activation flow.
        if (_iid.length == 0) {
            _iid = [[[NSUUID UUID] UUIDString] lowercaseString];
            [self persistSession];
        }
    }
    return self;
}

- (BOOL)isLoggedIn { return (self.token.length > 0); }

- (void)logout {
    self.token = nil; self.refreshToken = nil;
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    [u removeObjectForKey:@"lubika.token"];
    [u removeObjectForKey:@"lubika.refresh"];
    [u synchronize];
}

- (void)persistSession {
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    if (self.token) [u setObject:self.token forKey:@"lubika.token"];
    if (self.refreshToken) [u setObject:self.refreshToken forKey:@"lubika.refresh"];
    if (self.iid) [u setObject:self.iid forKey:@"lubika.iid"];
    if (self.cardNumber) [u setObject:self.cardNumber forKey:@"lubika.card"];
    if (self.expirationDateTime) [u setObject:self.expirationDateTime forKey:@"lubika.exp"];
    [u synchronize];
}

- (NSMutableURLRequest *)requestForPath:(NSString *)path method:(NSString *)method {
    NSURL *url = [NSURL URLWithString:path relativeToURL:[NSURL URLWithString:self.baseURL]];
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:url];
    r.HTTPMethod = method;
    r.timeoutInterval = 30.0;
    [r setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [r setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [r setValue:@"pl" forHTTPHeaderField:@"Accept-Language"];
    [r setValue:self.verHeader forHTTPHeaderField:@"ver"];
    if (self.token.length)  [r setValue:[@"Bearer " stringByAppendingString:self.token]
                     forHTTPHeaderField:@"Authorization"];
    if (self.iid.length)    [r setValue:self.iid forHTTPHeaderField:@"iid"];
    return r;
}

// Runs an async request, parses the BaseDto envelope, returns `data` node.
// On 401 it transparently refreshes the access token once and retries.
- (void)send:(NSURLRequest *)req completion:(void (^)(NSDictionary *data, NSError *err))done {
    [self send:req allowRefresh:YES completion:done];
}

- (void)send:(NSURLRequest *)req allowRefresh:(BOOL)allowRefresh
  completion:(void (^)(NSDictionary *data, NSError *err))done {
    LubikaLog(@"--> %@ %@ | iid=%@ | auth=%@ | ver=%@ | body=%@",
              req.HTTPMethod, req.URL.absoluteString,
              [req valueForHTTPHeaderField:@"iid"],
              ([req valueForHTTPHeaderField:@"Authorization"] ? @"yes" : @"no"),
              [req valueForHTTPHeaderField:@"ver"],
              // Never log the login body (it contains the password).
              ([req.URL.path rangeOfString:@"login"].location != NSNotFound ? @"(hidden)" :
               (req.HTTPBody ? [[NSString alloc] initWithData:req.HTTPBody encoding:NSUTF8StringEncoding] : @"(none)")));
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *resp, NSData *body, NSError *netErr) {
        NSInteger httpCode = [(NSHTTPURLResponse *)resp statusCode];
        id root = body.length ? [NSJSONSerialization JSONObjectWithData:body options:0 error:NULL] : nil;
        NSDictionary *dict = [root isKindOfClass:[NSDictionary class]] ? root : nil;
        // iOS 6 / the TLS shim reports statusCode 0 for some errors (e.g. 401),
        // but the BaseDto envelope carries the real "status". Use that as fallback.
        NSInteger envStatus = [dict[@"status"] respondsToSelector:@selector(integerValue)]
                              ? [dict[@"status"] integerValue] : 0;
        NSInteger status = httpCode > 0 ? httpCode : envStatus;

        NSString *bs = body.length ? [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding] : @"(empty)";
        if (bs.length > 300) bs = [bs substringToIndex:300];
        LubikaLog(@"<-- http=%ld status=%ld %@ | %@", (long)httpCode, (long)status, req.URL.path, bs);

        if (netErr) { if (done) done(nil, netErr); return; }

        // Access token expired -> refresh once and retry the original request.
        if (status == 401 && allowRefresh && self.refreshToken.length) {
            [self refreshTokenThen:^(BOOL ok) {
                if (ok) {
                    NSMutableURLRequest *retry = [req mutableCopy];
                    [retry setValue:[@"Bearer " stringByAppendingString:self.token]
                 forHTTPHeaderField:@"Authorization"];
                    [self send:retry allowRefresh:NO completion:done];
                } else {
                    NSError *e = [NSError errorWithDomain:@"Lubika" code:401
                        userInfo:@{NSLocalizedDescriptionKey:@"Sesja wygasła. Zaloguj się ponownie."}];
                    if (done) done(nil, e);
                }
            }];
            return;
        }

        if (!dict) {
            NSError *e = [NSError errorWithDomain:@"Lubika" code:status
                          userInfo:@{NSLocalizedDescriptionKey:@"Błędna odpowiedź serwera"}];
            if (done) done(nil, e);
            return;
        }
        id data = dict[@"data"];
        // A success envelope may carry data==nil with an empty errors[] (e.g.
        // Sms/iid/verify); only a >=400 status or a non-empty errors[] is a failure.
        id errs = dict[@"errors"];
        BOOL hasErrs = [errs isKindOfClass:[NSArray class]] && [(NSArray *)errs count] > 0;
        if (status >= 400 || hasErrs) {
            NSString *msg = dict[@"description"];
            if (!msg || msg == (id)[NSNull null]) {
                if (hasErrs) {
                    id first = [(NSArray *)errs objectAtIndex:0];
                    if ([first isKindOfClass:[NSDictionary class]])
                        msg = first[@"message"] ?: first[@"description"] ?: [first description];
                    else msg = [first description];
                }
            }
            if (!msg || msg == (id)[NSNull null]) msg = dict[@"title"];
            if (!msg || msg == (id)[NSNull null]) msg = [NSString stringWithFormat:@"Błąd %ld", (long)status];
            NSError *e = [NSError errorWithDomain:@"Lubika" code:status
                          userInfo:@{NSLocalizedDescriptionKey: msg}];
            if (done) done(nil, e);
            return;
        }
        if (done) done([data isKindOfClass:[NSDictionary class]] ? data : nil, nil);
    }];
}

- (void)refreshTokenThen:(void (^)(BOOL ok))done {
    NSMutableURLRequest *r = [self requestForPath:@"Account/token/refresh" method:@"POST"];
    NSDictionary *body = @{ @"accessToken":        self.token ?: @"",
                            @"refreshToken":       self.refreshToken ?: @"",
                            @"expirationDateTime": self.expirationDateTime ?: @"",
                            @"pushToken":          @"" };
    r.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
    [self send:r allowRefresh:NO completion:^(NSDictionary *data, NSError *err) {
        if (!err && [data isKindOfClass:[NSDictionary class]] &&
            [data[@"token"] isKindOfClass:[NSString class]]) {
            self.token = data[@"token"];
            if ([data[@"refreshToken"] isKindOfClass:[NSString class]])
                self.refreshToken = data[@"refreshToken"];
            if ([data[@"expirationDateTime"] isKindOfClass:[NSString class]])
                self.expirationDateTime = data[@"expirationDateTime"];
            [self persistSession];
            if (done) done(YES);
        } else {
            if (done) done(NO);
        }
    }];
}

- (void)loginWithUsername:(NSString *)username
                 password:(NSString *)password
               completion:(void (^)(NSDictionary *, NSError *))completion {
    NSMutableURLRequest *r = [self requestForPath:@"Account/login" method:@"POST"];
    NSDictionary *bodyObj = @{ @"username": username ?: @"",
                               @"password": password ?: @"",
                               @"pushToken": @"" };
    r.HTTPBody = [NSJSONSerialization dataWithJSONObject:bodyObj options:0 error:NULL];
    [self send:r completion:^(NSDictionary *data, NSError *err) {
        if (!err && data) {
            self.token        = data[@"token"];
            self.refreshToken = data[@"refreshToken"];
            if ([data[@"expirationDateTime"] isKindOfClass:[NSString class]])
                self.expirationDateTime = data[@"expirationDateTime"];
            id card = data[@"card"];
            if ([card isKindOfClass:[NSDictionary class]]) {
                id num = card[@"number"];
                if ([num isKindOfClass:[NSString class]]) self.cardNumber = num;
            }
            [self persistSession];
        }
        if (completion) completion(data, err);
    }];
}

- (void)getUserWithCompletion:(void (^)(NSDictionary *, NSError *))completion {
    [self send:[self requestForPath:@"Account/user" method:@"GET"]
     completion:^(NSDictionary *data, NSError *err) {
        if (!err && [data isKindOfClass:[NSDictionary class]]) {
            self.user = data;   // cache full profile for the UI
            id card = data[@"card"];
            if ([card isKindOfClass:[NSDictionary class]]) {
                id num = card[@"number"];
                if ([num isKindOfClass:[NSString class]]) {
                    self.cardNumber = num;
                    [self persistSession];
                }
            }
        }
        if (completion) completion(data, err);
    }];
}

- (void)getPhotoWithCompletion:(void (^)(UIImage *, NSError *))completion {
    [self send:[self requestForPath:@"Account/photo" method:@"GET"]
     completion:^(NSDictionary *data, NSError *err) {
        if (!err && [data isKindOfClass:[NSDictionary class]]) {
            id photo = data[@"photo"];
            NSString *b64 = [photo isKindOfClass:[NSDictionary class]] ? photo[@"base64"] : nil;
            if ([b64 isKindOfClass:[NSString class]]) {
                UIImage *img = [LubikaClient imageFromBase64:b64];
                if (img) self.photo = img;
            }
        }
        if (completion) completion(self.photo, err);
    }];
}

- (NSString *)firstName {
    id c = self.user[@"client"];
    return [c isKindOfClass:[NSDictionary class]] ? c[@"firstName"] : nil;
}
- (NSString *)lastName {
    id c = self.user[@"client"];
    return [c isKindOfClass:[NSDictionary class]] ? c[@"lastName"] : nil;
}
- (NSString *)displayName {
    id d = self.user[@"displayName"];
    if ([d isKindOfClass:[NSString class]] && [d length]) return d;
    return [self firstName];
}
- (NSString *)email {
    id e = self.user[@"email"];
    return [e isKindOfClass:[NSString class]] ? e : nil;
}
- (NSString *)balanceText {
    id card = self.user[@"card"];
    id purse = [card isKindOfClass:[NSDictionary class]] ? card[@"purseState"] : nil;
    id bal = [purse isKindOfClass:[NSDictionary class]] ? purse[@"balance"] : nil;
    if (bal == nil || bal == (id)[NSNull null]) return nil;
    double v = [bal respondsToSelector:@selector(doubleValue)] ? [bal doubleValue] : 0;
    NSString *num = [[NSString stringWithFormat:@"%.2f", v]
                     stringByReplacingOccurrencesOfString:@"." withString:@","];
    return [num stringByAppendingString:@" zł"];
}

- (void)getControlQRForType:(LubikaQRType)type
                 completion:(void (^)(id, NSDictionary *, NSError *))completion {
    NSString *path = [NSString stringWithFormat:@"TicketControl/qrcode?type=%c", (char)type];
    [self send:[self requestForPath:path method:@"GET"] completion:^(NSDictionary *data, NSError *err) {
        id image = nil;
        if (!err && data) {
            NSString *b64 = data[@"bitmapImage"];
            if ([b64 isKindOfClass:[NSString class]]) {
                image = [LubikaClient imageFromBase64:b64];
            }
        }
        if (completion) completion(image, data, err);
    }];
}

// The iid is a client-chosen random UUID (matches Android's SplashViewModel:
// UUID.randomUUID().toString()). We generate it once, send it in the `iid` header,
// and the SMS verify step binds *this* value to the account server-side.
- (NSString *)ensureIid {
    if (self.iid.length == 0) {
        self.iid = [[[NSUUID UUID] UUIDString] lowercaseString];  // Android uses lowercase
        [self persistSession];
    }
    return self.iid;
}

// POST Sms/iid/generate  -> server sends an SMS code to the account's phone.
// Body mirrors GenerateCodeRequest; for the iid flow only phoneNumber is sent.
- (void)generateIidSmsForPhone:(NSString *)phone
                    completion:(void (^)(NSDictionary *, NSError *))completion {
    [self ensureIid];   // make sure the iid header carries our UUID before binding
    NSMutableURLRequest *r = [self requestForPath:@"Sms/iid/generate" method:@"POST"];
    NSDictionary *body = @{ @"phoneNumber": phone ?: @"" };
    r.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
    [self send:r completion:completion];
}

// POST Sms/iid/verify  -> on success the iid we are sending is now bound to the
// account (VerifySmsRequest: phoneNumber + code; response is a bare envelope).
- (void)verifyIidSmsForPhone:(NSString *)phone code:(NSString *)code
                  completion:(void (^)(NSDictionary *, NSError *))completion {
    [self ensureIid];
    NSMutableURLRequest *r = [self requestForPath:@"Sms/iid/verify" method:@"POST"];
    NSDictionary *body = @{ @"phoneNumber": phone ?: @"", @"code": code ?: @"" };
    r.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
    [self send:r completion:^(NSDictionary *data, NSError *err) {
        if (!err) [self persistSession];   // keep the now-bound iid
        if (completion) completion(data, err);
    }];
}

+ (UIImage *)imageFromBase64:(NSString *)b64 {
    if (!b64.length) return nil;
    // strip a possible data-URI prefix and whitespace
    NSRange c = [b64 rangeOfString:@"base64,"];
    if (c.location != NSNotFound) b64 = [b64 substringFromIndex:c.location + c.length];
    b64 = [b64 stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    b64 = [b64 stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    b64 = [b64 stringByReplacingOccurrencesOfString:@" "  withString:@""];
    NSData *data = nil;
    // NSData base64 decoder from iOS 7 isn't on iOS 6; use the deprecated one.
#if __IPHONE_OS_VERSION_MIN_REQUIRED < 70000
    data = [[NSData alloc] initWithBase64Encoding:b64];
#else
    data = [[NSData alloc] initWithBase64EncodedString:b64 options:0];
#endif
    return data ? [UIImage imageWithData:data] : nil;
}

@end
