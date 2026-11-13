#import "LoginViewController.h"
#import "LubikaClient.h"
#import "HomeViewController.h"
#import "Theme.h"

@interface LoginViewController () <UITextFieldDelegate>
@end

@implementation LoginViewController {
    UITextField *_user, *_pass;
    UIButton    *_go;
    UILabel     *_status;
    UIActivityIndicatorView *_spin;
}

- (void)loadView {
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Lubika — logowanie";
    LubikaApplyBackground(self.view);
    CGFloat w = self.view.bounds.size.width, x = 20, fw = w - 40;

    UILabel *h = [[UILabel alloc] initWithFrame:CGRectMake(x, 80, fw, 30)];
    h.text = @"Zaloguj się do konta Lubika"; h.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:h];

    _user = [self fieldAt:130 placeholder:@"E-mail / login"];
    _user.keyboardType = UIKeyboardTypeEmailAddress;
    _user.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _user.autocorrectionType = UITextAutocorrectionTypeNo;
    _pass = [self fieldAt:180 placeholder:@"Hasło"];
    _pass.secureTextEntry = YES;

    _user.delegate = self; _pass.delegate = self;
    _user.returnKeyType = UIReturnKeyNext;
    _pass.returnKeyType = UIReturnKeyGo;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:tap];

    _go = [UIButton buttonWithType:UIButtonTypeCustom];
    _go.frame = CGRectMake(x, 240, fw, 46);
    _go.backgroundColor = LubikaMagenta();
    _go.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    _go.layer.cornerRadius = 8; _go.layer.masksToBounds = YES;
    [_go setTitle:@"Zaloguj" forState:UIControlStateNormal];
    [_go setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_go addTarget:self action:@selector(doLogin) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_go];

    _spin = [[UIActivityIndicatorView alloc]
             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _spin.center = CGPointMake(w/2, 300); _spin.hidesWhenStopped = YES;
    [self.view addSubview:_spin];

    _status = [[UILabel alloc] initWithFrame:CGRectMake(x, 330, fw, 80)];
    _status.numberOfLines = 0; _status.textColor = [UIColor redColor];
    _status.textAlignment = NSTextAlignmentCenter; _status.font = [UIFont systemFontOfSize:13];
    [self.view addSubview:_status];
}

- (UITextField *)fieldAt:(CGFloat)y placeholder:(NSString *)p {
    UITextField *f = [[UITextField alloc]
        initWithFrame:CGRectMake(20, y, self.view.bounds.size.width - 40, 36)];
    f.placeholder = p; f.borderStyle = UITextBorderStyleRoundedRect;
    [self.view addSubview:f];
    return f;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([LubikaClient shared].loggedIn) [self openTickets];
}

- (void)dismissKeyboard {
    [_user resignFirstResponder];
    [_pass resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf {
    if (tf == _user) {
        [_pass becomeFirstResponder];
    } else {
        [tf resignFirstResponder];
        [self doLogin];
    }
    return YES;
}

- (void)doLogin {
    if (!_user.text.length || !_pass.text.length) { _status.text = @"Podaj login i hasło."; return; }
    [_spin startAnimating]; _go.enabled = NO; _status.text = @"";
    [[LubikaClient shared] loginWithUsername:_user.text password:_pass.text
        completion:^(NSDictionary *data, NSError *error) {
            [_spin stopAnimating]; _go.enabled = YES;
            if (error) { _status.text = error.localizedDescription; return; }
            if ([data[@"activationRequired"] boolValue]) {
                _status.text = @"Konto wymaga aktywacji nośnika (iid/SMS).";
            }
            [self openTickets];
        }];
}

- (void)openTickets {
    HomeViewController *home = [[HomeViewController alloc] init];
    [self.navigationController pushViewController:home animated:YES];
}

@end
