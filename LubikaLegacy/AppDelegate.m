#import <UIKit/UIKit.h>
#import "LoginViewController.h"
#import "Theme.h"

static void LaunchMark(NSString *s);

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
  didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    LaunchMark(@"didFinishLaunching start");
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    UINavigationBar *bar = [UINavigationBar appearance];
    bar.tintColor = LubikaMagenta();
    if ([bar respondsToSelector:@selector(setBarTintColor:)]) bar.barTintColor = LubikaMagenta();
    [bar setTitleTextAttributes:@{ NSForegroundColorAttributeName : [UIColor whiteColor] }];
    [[UIBarButtonItem appearance] setTitleTextAttributes:
        @{ NSForegroundColorAttributeName : [UIColor whiteColor] } forState:UIControlStateNormal];

    LoginViewController *login = [[LoginViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc]
                                   initWithRootViewController:login];
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    return YES;
}

@end

static void LaunchMark(NSString *s) {
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [NSDate date], s];
    NSString *p = @"/tmp/lubika_launch.log";
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:p];
    if (!fh) { [line writeToFile:p atomically:NO encoding:NSUTF8StringEncoding error:NULL]; return; }
    [fh seekToEndOfFile]; [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [fh closeFile];
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        LaunchMark(@"main() reached");
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
