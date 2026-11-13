#import "HomeViewController.h"
#import "ProfileViewController.h"
#import "SquareAnimationView.h"
#import "LubikaClient.h"
#import "Theme.h"

static const NSTimeInterval kRefresh = 30.0;   //refresh QR code every 30s

@interface HomeViewController () <UIAlertViewDelegate>
@end

@implementation HomeViewController {
    UIButton    *_photoBtn;
    UIScrollView *_scroll;
    UILabel     *_greeting, *_subtitle, *_balance, *_ticketTitle, *_ticketSub;
    UIImageView *_qr;
    SquareAnimationView *_squares;
    UILabel     *_info;
    UIActivityIndicatorView *_spin;
    NSTimer     *_refreshTimer;
    NSString    *_phone;
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Lubika";
    self.navigationItem.hidesBackButton = YES;
    LubikaApplyBackground(self.view);
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Aktywuj" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(activate)];

    CGFloat w = self.view.bounds.size.width, x = 16;

    _scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scroll.backgroundColor = [UIColor clearColor];
    _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scroll.alwaysBounceVertical = YES;
    [self.view addSubview:_scroll];

    _photoBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _photoBtn.frame = CGRectMake(x, 12, 56, 56);
    _photoBtn.backgroundColor = [UIColor colorWithWhite:0.93 alpha:1];
    _photoBtn.adjustsImageWhenHighlighted = NO;
    _photoBtn.imageView.contentMode = UIViewContentModeScaleAspectFill;
    [_photoBtn addTarget:self action:@selector(openProfile) forControlEvents:UIControlEventTouchUpInside];
    [_scroll addSubview:_photoBtn];
    LubikaMakeCircular(_photoBtn);

    _greeting = [[UILabel alloc] initWithFrame:CGRectMake(84, 16, w-100, 24)];
    _greeting.font = [UIFont boldSystemFontOfSize:19];
    _greeting.text = @"Cześć!";
    [_scroll addSubview:_greeting];

    _subtitle = [[UILabel alloc] initWithFrame:CGRectMake(84, 42, w-100, 18)];
    _subtitle.font = [UIFont systemFontOfSize:13];
    _subtitle.textColor = LubikaGray();
    _subtitle.text = @"Czas na podróż?";
    [_scroll addSubview:_subtitle];

    _balance = [[UILabel alloc] initWithFrame:CGRectMake(x, 78, w-2*x, 26)];
    _balance.font = [UIFont boldSystemFontOfSize:20];
    _balance.textColor = LubikaMagenta();
    [_scroll addSubview:_balance];

    // --- ticket card ---
    _ticketTitle = [[UILabel alloc] initWithFrame:CGRectMake(x, 112, w-2*x, 22)];
    _ticketTitle.font = [UIFont boldSystemFontOfSize:17];
    _ticketTitle.text = @"Okresowy";
    [_scroll addSubview:_ticketTitle];

    _ticketSub = [[UILabel alloc] initWithFrame:CGRectMake(x, 134, w-2*x, 16)];
    _ticketSub.font = [UIFont systemFontOfSize:12];
    _ticketSub.textColor = LubikaGray();
    _ticketSub.text = @"Bilet okresowy - kod kontroli";
    [_scroll addSubview:_ticketSub];

    CGFloat side = w - 100;
    CGFloat qrY = 154;
    _qr = [[UIImageView alloc] initWithFrame:CGRectMake((w-side)/2, qrY, side, side)];
    _qr.contentMode = UIViewContentModeScaleAspectFit;
    _qr.backgroundColor = [UIColor colorWithWhite:0.97 alpha:1];
    [_scroll addSubview:_qr];

    _spin = [[UIActivityIndicatorView alloc]
             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _spin.center = CGPointMake(w/2, qrY + side/2); _spin.hidesWhenStopped = YES;
    [_scroll addSubview:_spin];

    _squares = [[SquareAnimationView alloc] initWithFrame:CGRectMake(x, qrY + side + 8, w-2*x, 40)];
    [_scroll addSubview:_squares];

    _info = [[UILabel alloc] initWithFrame:CGRectMake(x, qrY + side + 54, w-2*x, 36)];
    _info.textAlignment = NSTextAlignmentCenter; _info.numberOfLines = 0;
    _info.font = [UIFont systemFontOfSize:12]; _info.textColor = LubikaGray();
    _info.text = @"Pokaż ten kod kontrolerowi.";
    [_scroll addSubview:_info];

    _scroll.contentSize = CGSizeMake(w, CGRectGetMaxY(_info.frame) + 20);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyProfile];
    [self loadProfile];
    [self reload];
    [_squares startAnimating];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_refreshTimer invalidate]; _refreshTimer = nil;
    [_squares stopAnimating];
}

- (void)loadProfile {
    LubikaClient *c = [LubikaClient shared];
    [c getUserWithCompletion:^(NSDictionary *data, NSError *error) { [self applyProfile]; }];
    if (!c.photo) [c getPhotoWithCompletion:^(UIImage *p, NSError *e) { [self applyProfile]; }];
}

- (void)applyProfile {
    LubikaClient *c = [LubikaClient shared];
    NSString *name = c.firstName;
    _greeting.text = name.length ? [NSString stringWithFormat:@"Cześć, %@!", name] : @"Cześć!";
    NSString *bal = c.balanceText;
    _balance.text = bal.length ? [@"Saldo: " stringByAppendingString:bal] : @"";
    if (c.photo) [_photoBtn setImage:c.photo forState:UIControlStateNormal];
}

- (void)reload {
    [_refreshTimer invalidate];
    [self fetch];
    _refreshTimer = [NSTimer scheduledTimerWithTimeInterval:kRefresh target:self
                      selector:@selector(fetch) userInfo:nil repeats:YES];
}

- (void)fetch {
    [_spin startAnimating];
    [[LubikaClient shared] getControlQRForType:LubikaQRPeriodic
        completion:^(id image, NSDictionary *data, NSError *error) {
            [_spin stopAnimating];
            if (error) {
                _info.textColor = [UIColor redColor];
                _info.text = error.localizedDescription;
                return;
            }
            _info.textColor = LubikaGray();
            if (image) {
                _qr.image = image;
                _info.text = @"Pokaż ten kod kontrolerowi.";
            } else {
                _qr.image = nil;
                _info.text = [NSString stringWithFormat:@"Brak obrazka. %@", data[@"sourceData"]];
            }
        }];
}

- (void)openProfile {
    [self.navigationController pushViewController:[[ProfileViewController alloc] init] animated:YES];
}

#pragma mark - SMS device activation

- (void)activate {
    UIAlertView *a = [[UIAlertView alloc]
        initWithTitle:@"Aktywacja urządzenia"
              message:@"Potwierdź numer nośnika konta. Otrzymasz SMS z kodem.\nUWAGA: aktywacja dezaktywuje inne urządzenie."
             delegate:self cancelButtonTitle:@"Anuluj" otherButtonTitles:@"Wyślij SMS", nil];
    a.alertViewStyle = UIAlertViewStylePlainTextInput;
    a.tag = 1;
    UITextField *tf = [a textFieldAtIndex:0];
    tf.keyboardType = UIKeyboardTypePhonePad;
    tf.placeholder = @"numer nośnika";
    NSString *prefill = _phone.length ? _phone : [LubikaClient shared].cardNumber;
    if (prefill.length) tf.text = prefill;
    [a show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex) return;
    NSString *text = [[alertView textFieldAtIndex:0] text];
    if (alertView.tag == 1) {
        _phone = [text copy];
        _info.textColor = LubikaGray(); _info.text = @"Wysyłanie SMS..."; [_spin startAnimating];
        [[LubikaClient shared] generateIidSmsForPhone:_phone
            completion:^(NSDictionary *data, NSError *error) {
                [_spin stopAnimating];
                if (error) { _info.textColor = [UIColor redColor]; _info.text = error.localizedDescription; return; }
                UIAlertView *c = [[UIAlertView alloc] initWithTitle:@"Kod SMS"
                    message:@"Wpisz kod otrzymany w SMS." delegate:self
                    cancelButtonTitle:@"Anuluj" otherButtonTitles:@"Aktywuj", nil];
                c.alertViewStyle = UIAlertViewStylePlainTextInput; c.tag = 2;
                [c textFieldAtIndex:0].keyboardType = UIKeyboardTypeNumberPad;
                [c show];
            }];
    } else if (alertView.tag == 2) {
        _info.textColor = LubikaGray(); _info.text = @"Weryfikacja kodu..."; [_spin startAnimating];
        [[LubikaClient shared] verifyIidSmsForPhone:_phone code:text
            completion:^(NSDictionary *data, NSError *error) {
                [_spin stopAnimating];
                if (error) { _info.textColor = [UIColor redColor]; _info.text = error.localizedDescription; return; }
                _info.textColor = LubikaGray(); _info.text = @"Aktywowano. Pobieranie kodu...";
                [self reload];
            }];
    }
}

@end
