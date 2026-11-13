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

static inline void LubikaMakeCircular(UIView *v) {
    v.layer.cornerRadius = v.bounds.size.width / 2.0;
    v.layer.masksToBounds = YES;
    v.layer.borderWidth = 2.0;
    v.layer.borderColor = LubikaMagenta().CGColor;
}
