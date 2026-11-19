#import "TicketDetailViewController.h"
#import "SquareAnimationView.h"
#import "LubikaClient.h"
#import "Theme.h"

static const NSTimeInterval kRefresh = 30.0;

@implementation TicketDetailViewController {
    UIScrollView *_scroll;
    UIImageView  *_qr;
    SquareAnimationView *_squares;
    UIActivityIndicatorView *_spin;
    UILabel *_subtitle;
    UILabel *_vFrom, *_vTo, *_lines, *_zone;
    UIView  *_barFill; CGFloat _barMaxW;
    UILabel *_countdown, *_info;
    NSDate  *_vfDate, *_vtDate;
    NSTimer *_refreshTimer, *_tickTimer;
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Szczegóły biletu";
    LubikaApplyBackground(self.view);

    CGFloat w = self.view.bounds.size.width, x = 16;
    _scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    _scroll.backgroundColor = [UIColor clearColor];
    _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _scroll.alwaysBounceVertical = YES;
    [self.view addSubview:_scroll];

    // header
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(x, 12, w-2*x, 24)];
    title.font = [UIFont boldSystemFontOfSize:19]; title.text = @"Okresowy";
    [_scroll addSubview:title];

    _subtitle = [[UILabel alloc] initWithFrame:CGRectMake(x, 36, w-2*x, 32)];
    _subtitle.font = [UIFont systemFontOfSize:12]; _subtitle.textColor = LubikaGray();
    _subtitle.numberOfLines = 2; _subtitle.text = @"Bilet okresowy — kod kontroli";
    [_scroll addSubview:_subtitle];

    CGFloat side = w - 100, qrY = 78;
    _qr = [[UIImageView alloc] initWithFrame:CGRectMake((w-side)/2, qrY, side, side)];
    _qr.contentMode = UIViewContentModeScaleAspectFit;
    _qr.backgroundColor = [UIColor clearColor];
    [_scroll addSubview:_qr];

    _spin = [[UIActivityIndicatorView alloc]
             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _spin.center = CGPointMake(w/2, qrY + side/2); _spin.hidesWhenStopped = YES;
    [_scroll addSubview:_spin];

    _squares = [[SquareAnimationView alloc] initWithFrame:CGRectMake(x, qrY+side+6, w-2*x, 34)];
    [_scroll addSubview:_squares];

    _info = [[UILabel alloc] initWithFrame:CGRectMake(x, qrY+side+42, w-2*x, 16)];
    _info.textAlignment = NSTextAlignmentCenter; _info.font = [UIFont systemFontOfSize:12];
    _info.textColor = LubikaGray(); _info.text = @"Pokaż ten kod kontrolerowi.";
    [_scroll addSubview:_info];

    CGFloat gy = qrY + side + 70, gap = 10;
    CGFloat cw = (w - 2*x - gap) / 2.0, ch = 60;
    _vFrom = [self cardAt:CGRectMake(x,            gy,        cw, ch) title:@"Ważny od"];
    _vTo   = [self cardAt:CGRectMake(x+cw+gap,     gy,        cw, ch) title:@"Ważny do"];
    _lines = [self cardAt:CGRectMake(x,            gy+ch+gap, cw, ch) title:@"Linie"];
    _zone  = [self cardAt:CGRectMake(x+cw+gap,     gy+ch+gap, cw, ch) title:@"Strefa"];

    CGFloat by = gy + 2*ch + gap + 18;
    UIView *track = [[UIView alloc] initWithFrame:CGRectMake(x, by, w-2*x, 8)];
    track.backgroundColor = [UIColor colorWithWhite:0.88 alpha:1];
    track.layer.cornerRadius = 4; track.layer.masksToBounds = YES;
    [_scroll addSubview:track];
    _barMaxW = w-2*x;
    _barFill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 8)];
    _barFill.backgroundColor = [UIColor colorWithRed:0.18 green:0.73 blue:0.37 alpha:1];
    [track addSubview:_barFill];

    _countdown = [[UILabel alloc] initWithFrame:CGRectMake(x, by+16, w-2*x, 24)];
    _countdown.textAlignment = NSTextAlignmentCenter;
    _countdown.font = [UIFont boldSystemFontOfSize:17];
    _countdown.textColor = [UIColor colorWithRed:0.14 green:0.6 blue:0.3 alpha:1];
    [_scroll addSubview:_countdown];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(x, by+40, w-2*x, 16)];
    sub.textAlignment = NSTextAlignmentCenter; sub.font = [UIFont systemFontOfSize:11];
    sub.textColor = LubikaGray(); sub.text = @"Pozostały czas do wygaśnięcia biletu";
    [_scroll addSubview:sub];

    _scroll.contentSize = CGSizeMake(w, by + 64);

    LubikaClearLabels(self.view);

    [self applyTicketData];
}

- (UILabel *)cardAt:(CGRect)r title:(NSString *)t {
    UIView *card = [[UIView alloc] initWithFrame:r];
    card.backgroundColor = [UIColor colorWithWhite:0.93 alpha:1];
    card.layer.cornerRadius = 8; card.layer.masksToBounds = YES;
    [_scroll addSubview:card];
    UILabel *cap = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, r.size.width-20, 14)];
    cap.font = [UIFont systemFontOfSize:11]; cap.textColor = LubikaGray(); cap.text = t;
    [card addSubview:cap];
    UILabel *val = [[UILabel alloc] initWithFrame:CGRectMake(10, 26, r.size.width-20, 26)];
    val.font = [UIFont boldSystemFontOfSize:17]; val.text = @"—";
    [card addSubview:val];
    return val;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [_squares startAnimating];
    _tickTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self
                   selector:@selector(tick) userInfo:nil repeats:YES];
    [self reload];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_squares stopAnimating];
    [_refreshTimer invalidate]; _refreshTimer = nil;
    [_tickTimer invalidate];    _tickTimer = nil;
}

- (void)applyTicketData {
    NSDictionary *td = [LubikaClient shared].periodicTicketData;
    NSString *vf = td[@"ticketValidityStartDate"];
    NSString *vt = td[@"ticketValidityEndDate"];
    if ([vf isKindOfClass:[NSString class]]) _vfDate = LubikaParseISO(vf);
    if ([vt isKindOfClass:[NSString class]]) _vtDate = LubikaParseISO(vt);
    _vFrom.text = LubikaFmtDate(_vfDate);
    _vTo.text   = LubikaFmtDate(_vtDate);
    NSString *lines = td[@"ticketValidLines"];
    _lines.text = ([lines isKindOfClass:[NSString class]] && lines.length) ? lines : @"wszystkie";
    [self tick];
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
            if (error) { _info.textColor = [UIColor redColor]; _info.text = error.localizedDescription; return; }
            _info.textColor = LubikaGray(); _info.text = @"Pokaż ten kod kontrolerowi.";
            if (image) _qr.image = image;
            [self applySourceData:data[@"sourceData"]];
        }];
}

- (void)applySourceData:(id)src {
    if (![src isKindOfClass:[NSDictionary class]]) return;
    id d = src[@"d"];
    NSDictionary *t = ([d isKindOfClass:[NSArray class]] && [(NSArray *)d count]) ?
                      [(NSArray *)d objectAtIndex:0] : nil;
    if (![t isKindOfClass:[NSDictionary class]]) return;
    if ([t[@"vf"] isKindOfClass:[NSString class]]) { _vfDate = LubikaParseISO(t[@"vf"]); _vFrom.text = LubikaFmtDate(_vfDate); }
    if ([t[@"vt"] isKindOfClass:[NSString class]]) { _vtDate = LubikaParseISO(t[@"vt"]); _vTo.text   = LubikaFmtDate(_vtDate); }
    if ([t[@"n"]  isKindOfClass:[NSString class]]) _subtitle.text = t[@"n"];
    id z = t[@"z"];
    if ([z isKindOfClass:[NSArray class]]) {
        long maxz = 0;
        for (id e in (NSArray *)z) if ([e respondsToSelector:@selector(longValue)] && [e longValue] > maxz) maxz = [e longValue];
        if (maxz > 0) _zone.text = [NSString stringWithFormat:@"%ld", maxz];
    }
    [self tick];
}

- (void)tick {
    if (!_vtDate) { _countdown.text = @""; return; }
    NSTimeInterval remain = [_vtDate timeIntervalSinceNow];
    if (remain < 0) remain = 0;
    long total = (long)remain;
    long days = total/86400, hrs = (total%86400)/3600, mins = (total%3600)/60, secs = total%60;
    _countdown.text = [NSString stringWithFormat:@"%ld dni %ld godz %ld min %ld sek", days, hrs, mins, secs];
    CGFloat frac = 0;
    if (_vfDate) {
        NSTimeInterval span = [_vtDate timeIntervalSinceDate:_vfDate];
        if (span > 0) frac = (CGFloat)(remain / span);
        if (frac < 0) frac = 0; if (frac > 1) frac = 1;
    }
    CGRect f = _barFill.frame; f.size.width = _barMaxW * frac; _barFill.frame = f;
}

@end
