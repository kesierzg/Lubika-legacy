#import "SquareAnimationView.h"
#import <QuartzCore/QuartzCore.h>

// Source Lottie: 30 fps, 40 frames; a square scaling 20% -> 86.667% (at frame 10)
// -> 20% (frame 39). Six copies, each random phase + random 0.5x-1.0x speed.
static const int    kCount    = 6;
static const double kBaseDur  = 40.0 / 30.0;   // one loop in seconds
static const double kPeakTime = 10.0 / 39.0;   // keyTime of the 86.667% peak

@implementation SquareAnimationView {
    NSMutableArray *_squares;   // CALayer*
}

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor clearColor];
        _squares = [NSMutableArray array];
        for (int i = 0; i < kCount; i++) {
            CALayer *l = [CALayer layer];
            l.backgroundColor = [UIColor blackColor].CGColor;
            [self.layer addSublayer:l];
            [_squares addObject:l];
        }
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat side = 26, gap = 14;
    CGFloat total = kCount * side + (kCount - 1) * gap;
    CGFloat startX = (self.bounds.size.width - total) / 2.0;
    CGFloat cy = self.bounds.size.height / 2.0;
    for (int i = 0; i < kCount; i++) {
        CALayer *l = _squares[i];
        l.bounds = CGRectMake(0, 0, side, side);
        l.position = CGPointMake(startX + side/2 + i * (side + gap), cy);
    }
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) [self startAnimating]; else [self stopAnimating];
}

- (double)rnd { return (double)arc4random_uniform(10000) / 10000.0; }  // 0..1

- (void)startAnimating {
    for (int i = 0; i < kCount; i++) {
        CALayer *l = _squares[i];
        [l removeAllAnimations];
        double speed = 0.5 + [self rnd] * 0.5;    // 0.5x .. 1.0x (slower..full)
        double dur   = kBaseDur / speed;
        CAKeyframeAnimation *a = [CAKeyframeAnimation animationWithKeyPath:@"transform.scale"];
        a.values   = @[ @0.20, @0.86667, @0.20 ];
        a.keyTimes = @[ @0.0, @(kPeakTime), @1.0 ];
        a.duration = dur;
        a.repeatCount = HUGE_VALF;
        a.removedOnCompletion = NO;
        a.calculationMode = kCAAnimationLinear;
        a.timeOffset = [self rnd] * dur;          // random starting phase
        [l addAnimation:a forKey:@"pulse"];
    }
}

- (void)stopAnimating {
    for (CALayer *l in _squares) [l removeAllAnimations];
}

@end
