#import "ProfileViewController.h"
#import "LubikaClient.h"
#import "Theme.h"

@implementation ProfileViewController {
    UIScrollView *_scroll;
    UIImageView  *_photo;
    UIImageView  *_qr;
    UILabel      *_qrCaption;
    UIActivityIndicatorView *_spin;
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Profil użytkownika";
    LubikaApplyBackground(self.view);

    CGFloat w = self.view.bounds.size.width, x = 20;
    _scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scroll.backgroundColor = [UIColor clearColor];
    _scroll.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_scroll];

    LubikaClient *c = [LubikaClient shared];

    CGFloat pw = 130, ph = 170;
    _photo = [[UIImageView alloc] initWithFrame:CGRectMake((w-pw)/2, 16, pw, ph)];
    _photo.contentMode = UIViewContentModeScaleAspectFill;
    _photo.clipsToBounds = YES;
    _photo.backgroundColor = [UIColor colorWithWhite:0.93 alpha:1];
    _photo.layer.borderWidth = 1; _photo.layer.borderColor = [UIColor colorWithWhite:0.85 alpha:1].CGColor;
    _photo.image = c.photo;
    [_scroll addSubview:_photo];

    CGFloat y = 16 + ph + 20;
    y = [self addField:@"Imię"            value:c.firstName atY:y width:w inset:x];
    y = [self addField:@"Nazwisko"        value:c.lastName  atY:y width:w inset:x];
    y = [self addField:@"E-mail"          value:c.email     atY:y width:w inset:x];
    y = [self addField:@"Numer telefonu"  value:c.cardNumber atY:y width:w inset:x];

    y += 10;
    _qrCaption = [[UILabel alloc] initWithFrame:CGRectMake(x, y, w-2*x, 18)];
    _qrCaption.font = [UIFont systemFontOfSize:13]; _qrCaption.textColor = LubikaGray();
    _qrCaption.textAlignment = NSTextAlignmentCenter;
    _qrCaption.text = @"Identyfikator aplikacji";
    [_scroll addSubview:_qrCaption];
    y += 24;

    CGFloat side = w - 120;
    _qr = [[UIImageView alloc] initWithFrame:CGRectMake((w-side)/2, y, side, side)];
    _qr.contentMode = UIViewContentModeScaleAspectFit;
    _qr.backgroundColor = [UIColor clearColor];
    [_scroll addSubview:_qr];

    _spin = [[UIActivityIndicatorView alloc]
             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _spin.center = CGPointMake(w/2, y + side/2); _spin.hidesWhenStopped = YES;
    [_scroll addSubview:_spin];

    y += side + 24;
    UIButton *out = [UIButton buttonWithType:UIButtonTypeCustom];
    out.frame = CGRectMake(x, y, w-2*x, 46);
    out.backgroundColor = LubikaMagenta();
    out.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    out.layer.cornerRadius = 8; out.layer.masksToBounds = YES;
    [out setTitle:@"Wyloguj" forState:UIControlStateNormal];
    [out setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [out addTarget:self action:@selector(logout) forControlEvents:UIControlEventTouchUpInside];
    [_scroll addSubview:out];
    y += 46;

    _scroll.contentSize = CGSizeMake(w, y + 24);
    LubikaClearLabels(self.view);
}

- (void)logout {
    [[LubikaClient shared] logout];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (CGFloat)addField:(NSString *)caption value:(NSString *)value
                atY:(CGFloat)y width:(CGFloat)w inset:(CGFloat)x {
    UILabel *cap = [[UILabel alloc] initWithFrame:CGRectMake(x, y, w-2*x, 15)];
    cap.font = [UIFont systemFontOfSize:12]; cap.textColor = LubikaGray();
    cap.text = caption;
    [_scroll addSubview:cap];

    UILabel *val = [[UILabel alloc] initWithFrame:CGRectMake(x, y+16, w-2*x, 22)];
    val.font = [UIFont systemFontOfSize:17]; val.textColor = [UIColor darkTextColor];
    val.text = (value.length ? value : @"—");
    [_scroll addSubview:val];

    UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(x, y+42, w-2*x, 0.5)];
    sep.backgroundColor = [UIColor colorWithWhite:0.85 alpha:1];
    [_scroll addSubview:sep];
    return y + 54;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    LubikaClient *c = [LubikaClient shared];
    if (!c.photo) [c getPhotoWithCompletion:^(UIImage *p, NSError *e) { if (p) _photo.image = p; }];
    [_spin startAnimating];
    [c getControlQRForType:LubikaQRUser
        completion:^(id image, NSDictionary *data, NSError *error) {
            [_spin stopAnimating];
            if (image) _qr.image = image;
            else if (error) { _qrCaption.textColor = [UIColor redColor];
                              _qrCaption.text = error.localizedDescription; }
        }];
}

@end
