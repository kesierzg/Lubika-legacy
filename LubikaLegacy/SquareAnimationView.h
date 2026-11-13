#import <UIKit/UIKit.h>

// Port of the Android app's "square animation" liveness indicator: a row of six
// black squares that pulse in scale, each with a random phase and speed, so they
// animate out of sync. Inspectors use the motion to confirm a live screen.
@interface SquareAnimationView : UIView
- (void)startAnimating;
- (void)stopAnimating;
@end
