#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static inline UIColor *LubikaMagenta(void) {
    return [UIColor colorWithRed:0xE5/255.0 green:0x00/255.0 blue:0x6C/255.0 alpha:1.0];
}

static inline UIColor *LubikaGray(void) {
    return [UIColor colorWithWhite:0.45 alpha:1.0];
}

static inline void LubikaApplyBackground(UIView *v) {
    v.backgroundColor = [UIColor whiteColor];
    UIImage *wm = [UIImage imageNamed:@"watermark"];
    if (wm) {
        CGFloat W = v.bounds.size.width;
        CGFloat h = wm.size.height * (W / wm.size.width);
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, W, h)];
        iv.image = wm;
        iv.contentMode = UIViewContentModeScaleToFill;
        iv.userInteractionEnabled = NO;
        iv.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [v insertSubview:iv atIndex:0];
    }
}

// Parse "2026-10-01T00:00:00+02:00" (or without TZ) into NSDate; nil on failure.
static inline NSDate *LubikaParseISO(NSString *s) {
    if (![s isKindOfClass:[NSString class]] || s.length < 19) return nil;
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    f.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
    NSDate *d = [f dateFromString:s];
    if (!d) { f.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss"; d = [f dateFromString:[s substringToIndex:19]]; }
    return d;
}

static inline NSString *LubikaFmtDate(NSDate *d) {
    if (!d) return @"—";
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    f.dateFormat = @"dd.MM.yyyy";
    return [f stringFromDate:d];
}

// On this iOS 6 build UILabel renders with an opaque white background by default,
// which shows as a white box around every piece of text. Recursively force all
// labels transparent so text sits directly on the background.
static inline void LubikaClearLabels(UIView *v) {
    for (UIView *sub in v.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) sub.backgroundColor = [UIColor clearColor];
        LubikaClearLabels(sub);
    }
}

static inline void LubikaMakeCircular(UIView *v) {
    v.layer.cornerRadius = v.bounds.size.width / 2.0;
    v.layer.masksToBounds = YES;
    v.layer.borderWidth = 2.0;
    v.layer.borderColor = LubikaMagenta().CGColor;
}
