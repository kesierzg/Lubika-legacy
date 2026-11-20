#import "HomeViewController.h"
#import "ProfileViewController.h"
#import "TicketDetailViewController.h"
#import "LubikaClient.h"
#import "Theme.h"

enum { IconStop = 1, IconTime, IconPeriodic, IconCalendar };

@interface HomeViewController () <UIAlertViewDelegate>
@end

@implementation HomeViewController {
    UIScrollView *_scroll;
    UIButton    *_photoBtn;
    UILabel     *_greeting, *_subtitle, *_balance;
    UIView      *_ticketCard;
    UILabel     *_dayBadge, *_cardTitle, *_cardSub;
    UILabel     *_status;
    UIActivityIndicatorView *_spin;
    NSString    *_phone;
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void)addPath:(UIBezierPath *)p to:(UIView *)v color:(UIColor *)c fill:(BOOL)fill {
    CAShapeLayer *s = [CAShapeLayer layer];
    s.path = p.CGPath; s.lineWidth = 2;
    s.strokeColor = c.CGColor;
    s.fillColor = fill ? c.CGColor : [UIColor clearColor].CGColor;
    s.lineCap = kCALineCapRound; s.lineJoin = kCALineJoinRound;
    [v.layer addSublayer:s];
}

- (void)drawIcon:(int)type in:(UIView *)v color:(UIColor *)c {
    CGFloat w = v.bounds.size.width, h = v.bounds.size.height;
    if (type == IconTime) {
        [self addPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(2,2,w-4,h-4)] to:v color:c fill:NO];
        UIBezierPath *hands = [UIBezierPath bezierPath];
        [hands moveToPoint:CGPointMake(w/2,h/2)]; [hands addLineToPoint:CGPointMake(w/2,h*0.28)];
        [hands moveToPoint:CGPointMake(w/2,h/2)]; [hands addLineToPoint:CGPointMake(w*0.72,h/2)];
        [self addPath:hands to:v color:c fill:NO];
    } else if (type == IconStop) {
        [self addPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(w*0.18,2,w*0.64,h*0.42) cornerRadius:3] to:v color:c fill:NO];
        UIBezierPath *pole = [UIBezierPath bezierPath];
        [pole moveToPoint:CGPointMake(w/2,h*0.46)]; [pole addLineToPoint:CGPointMake(w/2,h-3)];
        [pole moveToPoint:CGPointMake(w*0.36,h-3)]; [pole addLineToPoint:CGPointMake(w*0.64,h-3)];
        [self addPath:pole to:v color:c fill:NO];
    } else if (type == IconPeriodic) {
        [self addPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(1,h*0.2,w-2,h*0.6) cornerRadius:3] to:v color:c fill:NO];
        [self addPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(w*0.2,h*0.34,w*0.18,w*0.18)] to:v color:c fill:YES];
        UIBezierPath *lines = [UIBezierPath bezierPath];
        [lines moveToPoint:CGPointMake(w*0.5,h*0.42)]; [lines addLineToPoint:CGPointMake(w*0.82,h*0.42)];
        [lines moveToPoint:CGPointMake(w*0.5,h*0.56)]; [lines addLineToPoint:CGPointMake(w*0.82,h*0.56)];
        [self addPath:lines to:v color:c fill:NO];
    } else if (type == IconCalendar) {
        [self addPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(2,6,w-4,h-8) cornerRadius:5] to:v color:c fill:NO];
        UIBezierPath *rings = [UIBezierPath bezierPath];
        [rings moveToPoint:CGPointMake(w*0.3,1)]; [rings addLineToPoint:CGPointMake(w*0.3,9)];
        [rings moveToPoint:CGPointMake(w*0.7,1)]; [rings addLineToPoint:CGPointMake(w*0.7,9)];
        [self addPath:rings to:v color:c fill:NO];
    }
}

- (UIButton *)tileAt:(CGRect)r title:(NSString *)t subtitle:(NSString *)sub icon:(int)icon {
    UIButton *tile = [UIButton buttonWithType:UIButtonTypeCustom];
    tile.frame = r;
    tile.backgroundColor = LubikaMagenta();
    tile.layer.cornerRadius = 8; tile.layer.masksToBounds = YES;
    [tile addTarget:self action:@selector(buySoon) forControlEvents:UIControlEventTouchUpInside];

    UIView *ic = [[UIView alloc] initWithFrame:CGRectMake((r.size.width-30)/2, 16, 30, 30)];
    ic.backgroundColor = [UIColor clearColor]; ic.userInteractionEnabled = NO;
    [tile addSubview:ic];
    [self drawIcon:icon in:ic color:[UIColor whiteColor]];

    UILabel *tl = [[UILabel alloc] initWithFrame:CGRectMake(2, r.size.height-30, r.size.width-4, 16)];
    tl.text = t; tl.textAlignment = NSTextAlignmentCenter; tl.textColor = [UIColor whiteColor];
    tl.font = [UIFont boldSystemFontOfSize:12];
    tl.adjustsFontSizeToFitWidth = YES; tl.minimumScaleFactor = 0.7;
    [tile addSubview:tl];
    if (sub.length) {
        UILabel *sl = [[UILabel alloc] initWithFrame:CGRectMake(2, r.size.height-15, r.size.width-4, 12)];
        sl.text = sub; sl.textAlignment = NSTextAlignmentCenter; sl.textColor = [UIColor whiteColor];
        sl.font = [UIFont systemFontOfSize:9];
        sl.adjustsFontSizeToFitWidth = YES; sl.minimumScaleFactor = 0.7;
        [tile addSubview:sl];
    }
    return tile;
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

    _greeting = [[UILabel alloc] initWithFrame:CGRectMake(84, 18, w-100, 24)];
    _greeting.font = [UIFont boldSystemFontOfSize:19]; _greeting.text = @"Cześć!";
    [_scroll addSubview:_greeting];
    _subtitle = [[UILabel alloc] initWithFrame:CGRectMake(84, 44, w-100, 18)];
    _subtitle.font = [UIFont systemFontOfSize:13]; _subtitle.textColor = LubikaGray();
    _subtitle.text = @"Czas na podróż?";
    [_scroll addSubview:_subtitle];
    _balance = [[UILabel alloc] initWithFrame:CGRectMake(x, 80, w-2*x, 26)];
    _balance.font = [UIFont boldSystemFontOfSize:20]; _balance.textColor = LubikaMagenta();
    [_scroll addSubview:_balance];

    [_scroll addSubview:[self sectionLabel:@"Kup bilety" atY:116 width:w]];
    CGFloat ty = 150, th = 84, gap = 8, tw = (w - 2*x - 2*gap) / 3.0;
    [_scroll addSubview:[self tileAt:CGRectMake(x,              ty, tw, th) title:@"Przyst." subtitle:@"wejście/wyjście" icon:IconStop]];
    [_scroll addSubview:[self tileAt:CGRectMake(x+tw+gap,       ty, tw, th) title:@"Czasowy" subtitle:nil icon:IconTime]];
    [_scroll addSubview:[self tileAt:CGRectMake(x+2*(tw+gap),   ty, tw, th) title:@"Okresowy" subtitle:nil icon:IconPeriodic]];

    [_scroll addSubview:[self sectionLabel:@"Moje bilety" atY:252 width:w]];
    [self buildTicketCardAtY:286 width:w inset:x];

    _status = [[UILabel alloc] initWithFrame:CGRectMake(x, 392, w-2*x, 40)];
    _status.textAlignment = NSTextAlignmentCenter; _status.numberOfLines = 0;
    _status.font = [UIFont systemFontOfSize:12]; _status.textColor = LubikaGray();
    [_scroll addSubview:_status];
    _spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _spin.center = CGPointMake(w/2, 440); _spin.hidesWhenStopped = YES;
    [_scroll addSubview:_spin];

    _scroll.contentSize = CGSizeMake(w, 460);

    LubikaClearLabels(self.view);
    _dayBadge.backgroundColor = [UIColor clearColor];
}

- (UILabel *)sectionLabel:(NSString *)t atY:(CGFloat)y width:(CGFloat)w {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(16, y, w-32, 24)];
    l.font = [UIFont boldSystemFontOfSize:20]; l.text = t;
    return l;
}

- (void)buildTicketCardAtY:(CGFloat)y width:(CGFloat)w inset:(CGFloat)x {
    _ticketCard = [[UIView alloc] initWithFrame:CGRectMake(x, y, w-2*x, 96)];
    _ticketCard.backgroundColor = [UIColor whiteColor];
    _ticketCard.layer.cornerRadius = 12;
    _ticketCard.layer.borderWidth = 1;
    _ticketCard.layer.borderColor = [UIColor colorWithWhite:0.9 alpha:1].CGColor;
    [_scroll addSubview:_ticketCard];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openTicket)];
    [_ticketCard addGestureRecognizer:tap];

    UIView *cal = [[UIView alloc] initWithFrame:CGRectMake(12, 13, 70, 70)];
    cal.backgroundColor = [UIColor clearColor];
    [_ticketCard addSubview:cal];
    [self drawIcon:IconCalendar in:cal color:LubikaMagenta()];
    _dayBadge = [[UILabel alloc] initWithFrame:CGRectMake(0, 8, 70, 62)];
    _dayBadge.textAlignment = NSTextAlignmentCenter; _dayBadge.textColor = LubikaMagenta();
    _dayBadge.font = [UIFont boldSystemFontOfSize:24];
    _dayBadge.adjustsFontSizeToFitWidth = YES; _dayBadge.minimumScaleFactor = 0.6;
    [cal addSubview:_dayBadge];

    CAShapeLayer *dots = [CAShapeLayer layer];
    UIBezierPath *dp = [UIBezierPath bezierPath];
    [dp moveToPoint:CGPointMake(96, 16)]; [dp addLineToPoint:CGPointMake(96, 80)];
    dots.path = dp.CGPath; dots.strokeColor = LubikaMagenta().CGColor;
    dots.lineWidth = 3; dots.lineCap = kCALineCapRound; dots.lineDashPattern = @[@0.1, @7];
    [_ticketCard.layer addSublayer:dots];

    CGFloat tx = 110, tw = _ticketCard.bounds.size.width - tx - 12;
    _cardTitle = [[UILabel alloc] initWithFrame:CGRectMake(tx, 16, tw, 22)];
    _cardTitle.font = [UIFont boldSystemFontOfSize:17];
    [_ticketCard addSubview:_cardTitle];
    _cardSub = [[UILabel alloc] initWithFrame:CGRectMake(tx, 38, tw, 34)];
    _cardSub.font = [UIFont systemFontOfSize:12]; _cardSub.textColor = LubikaGray();
    _cardSub.numberOfLines = 2;
    [_ticketCard addSubview:_cardSub];
    UILabel *count = [[UILabel alloc] initWithFrame:CGRectMake(tx, 72, 100, 18)];
    count.font = [UIFont boldSystemFontOfSize:13]; count.textColor = [UIColor darkTextColor];
    count.text = @"◉ 1";
    [_ticketCard addSubview:count];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyProfile];
    [self loadProfile];
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

    NSDictionary *td = c.periodicTicketData;
    _ticketCard.hidden = (td == nil);
    if (td) {
        NSDate *vf = LubikaParseISO(td[@"ticketValidityStartDate"]);
        NSDate *vt = LubikaParseISO(td[@"ticketValidityEndDate"]);
        _cardTitle.text = @"Okresowy";
        long totalDays = (vf && vt) ? lround([vt timeIntervalSinceDate:vf] / 86400.0) + 1 : 0;
        NSString *lines = td[@"ticketValidLines"];
        if (![lines isKindOfClass:[NSString class]] || !lines.length) lines = @"wszystkie linie";
        _cardSub.text = [NSString stringWithFormat:@"Bilet %ld-dniowy, %@\nWażny do %@",
                         totalDays, lines, LubikaFmtDate(vt)];
        _dayBadge.text = totalDays > 0 ? [NSString stringWithFormat:@"%ld", totalDays] : @"—";
    }
}

- (void)buySoon {
    [[[UIAlertView alloc] initWithTitle:@"Kup bilety"
        message:@"Zakup biletów będzie dostępny wkrótce."
        delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

- (void)openTicket {
    if (![LubikaClient shared].periodicTicketData) return;
    [self.navigationController pushViewController:[[TicketDetailViewController alloc] init] animated:YES];
}

- (void)openProfile {
    [self.navigationController pushViewController:[[ProfileViewController alloc] init] animated:YES];
}

- (void)activate {
    UIAlertView *a = [[UIAlertView alloc]
        initWithTitle:@"Aktywacja urządzenia"
              message:@"Potwierdź numer nośnika konta. Otrzymasz SMS z kodem.\nUWAGA: aktywacja dezaktywuje inne urządzenie."
             delegate:self cancelButtonTitle:@"Anuluj" otherButtonTitles:@"Wyślij SMS", nil];
    a.alertViewStyle = UIAlertViewStylePlainTextInput; a.tag = 1;
    UITextField *tf = [a textFieldAtIndex:0];
    tf.keyboardType = UIKeyboardTypePhonePad; tf.placeholder = @"numer nośnika";
    NSString *prefill = _phone.length ? _phone : [LubikaClient shared].cardNumber;
    if (prefill.length) tf.text = prefill;
    [a show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == alertView.cancelButtonIndex) return;
    NSString *text = [[alertView textFieldAtIndex:0] text];
    if (alertView.tag == 1) {
        _phone = [text copy];
        _status.textColor = LubikaGray(); _status.text = @"Wysyłanie SMS..."; [_spin startAnimating];
        [[LubikaClient shared] generateIidSmsForPhone:_phone
            completion:^(NSDictionary *data, NSError *error) {
                [_spin stopAnimating];
                if (error) { _status.textColor = [UIColor redColor]; _status.text = error.localizedDescription; return; }
                UIAlertView *c = [[UIAlertView alloc] initWithTitle:@"Kod SMS"
                    message:@"Wpisz kod otrzymany w SMS." delegate:self
                    cancelButtonTitle:@"Anuluj" otherButtonTitles:@"Aktywuj", nil];
                c.alertViewStyle = UIAlertViewStylePlainTextInput; c.tag = 2;
                [c textFieldAtIndex:0].keyboardType = UIKeyboardTypeNumberPad;
                [c show];
            }];
    } else if (alertView.tag == 2) {
        _status.textColor = LubikaGray(); _status.text = @"Weryfikacja kodu..."; [_spin startAnimating];
        [[LubikaClient shared] verifyIidSmsForPhone:_phone code:text
            completion:^(NSDictionary *data, NSError *error) {
                [_spin stopAnimating];
                if (error) { _status.textColor = [UIColor redColor]; _status.text = error.localizedDescription; return; }
                _status.textColor = LubikaGray(); _status.text = @"Aktywowano.";
                [self loadProfile];
            }];
    }
}

@end
