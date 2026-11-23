//
//  PGRootViewController.m
//  两个 Tab：控制台（任务+日志）、设置（模型端点）。
//
#import "PGRootViewController.h"
#import "PGCommon.h"
#import "PGConfig.h"
#import "PGAgent.h"
#import "PGTouch.h"
#import "PGScreen.h"

@interface PGRootViewController () <PGAgentDelegate, UITabBarControllerDelegate>
@property (nonatomic, strong) UITextView *taskView;
@property (nonatomic, strong) UITextView *logView;
@property (nonatomic, strong) UIButton *runBtn;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation PGRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.title = @"PhoneGo";
    [PGAgent shared].delegate = self;
    [self buildUI];
    [self log:[NSString stringWithFormat:@"%@", [PGTouch shared].diagnosticInfo]];
    [self log:[NSString stringWithFormat:@"%@", [PGScreen shared].diagnosticInfo]];
}

- (void)buildUI {
    CGFloat w = self.view.bounds.size.width;
    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scroll];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, w - 40, 30)];
    title.text = @"PhoneGo · iOS 视觉 Agent";
    title.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    [scroll addSubview:title];

    UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(20, 54, w - 40, 40)];
    tip.text = @"输入任务→开始。截屏发给视觉模型，自动点击/滑动操作其他 App。切换 App 前保持本 App 在前台启动任务。";
    tip.font = [UIFont systemFontOfSize:13];
    tip.textColor = [UIColor secondaryLabelColor];
    tip.numberOfLines = 0;
    [scroll addSubview:tip];

    self.taskView = [[UITextView alloc] initWithFrame:CGRectMake(20, 104, w - 40, 90)];
    self.taskView.font = [UIFont systemFontOfSize:15];
    self.taskView.layer.cornerRadius = 8;
    self.taskView.layer.borderColor = [UIColor separatorColor].CGColor;
    self.taskView.layer.borderWidth = 1;
    self.taskView.text = @"打开设置，告诉我当前连接的 Wi-Fi 名称";
    [scroll addSubview:self.taskView];

    CGFloat by = 206;
    self.runBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.runBtn.frame = CGRectMake(20, by, (w - 50) / 2, 44);
    [self.runBtn setTitle:@"开始任务" forState:UIControlStateNormal];
    [self.runBtn.titleLabel setFont:[UIFont systemFontOfSize:16 weight:UIFontWeightMedium]];
    self.runBtn.backgroundColor = [UIColor systemBlueColor];
    [self.runBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.runBtn.layer.cornerRadius = 8;
    [self.runBtn addTarget:self action:@selector(runTapped) forControlEvents:UIControlEventTouchUpInside];
    [scroll addSubview:self.runBtn];

    UIButton *stopBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    stopBtn.frame = CGRectMake(20 + (w - 50) / 2 + 10, by, (w - 50) / 2, 44);
    [stopBtn setTitle:@"停止" forState:UIControlStateNormal];
    [stopBtn.titleLabel setFont:[UIFont systemFontOfSize:16 weight:UIFontWeightMedium]];
    stopBtn.backgroundColor = [UIColor systemRedColor];
    [stopBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    stopBtn.layer.cornerRadius = 8;
    [stopBtn addTarget:self action:@selector(stopTapped) forControlEvents:UIControlEventTouchUpInside];
    [scroll addSubview:stopBtn];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, by + 54, w - 40, 24)];
    self.statusLabel.text = @"就绪";
    self.statusLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.statusLabel.textColor = [UIColor systemGreenColor];
    [scroll addSubview:self.statusLabel];

    self.logView = [[UITextView alloc] initWithFrame:CGRectMake(20, by + 88, w - 40, 360)];
    self.logView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.logView.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    self.logView.layer.cornerRadius = 8;
    self.logView.editable = NO;
    self.logView.text = @"日志：\n";
    [scroll addSubview:self.logView];

    scroll.contentSize = CGSizeMake(w, by + 470);

    // 设置入口（右上角）
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"设置"
        style:UIBarButtonItemStylePlain target:self action:@selector(openSettings)];
}

- (void)log:(NSString *)line {
    NSString *old = self.logView.text ?: @"";
    self.logView.text = [old stringByAppendingFormat:@"\n%@", line];
    [self.logView scrollRangeToVisible:NSMakeRange(self.logView.text.length, 0)];
}

- (void)runTapped {
    [self.view endEditing:YES];
    if (![[PGConfig shared] isConfigured]) {
        [self log:@"⚠ 请先到「设置」填写 API Key 与 base URL"];
        [self openSettings];
        return;
    }
    [[PGAgent shared] runTask:self.taskView.text ?: @""];
}

- (void)stopTapped { [[PGAgent shared] stop]; }

- (void)openSettings {
    UIViewController *s = [[UIViewController alloc] init];
    s.title = @"设置";
    s.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    CGFloat w = s.view.bounds.size.width;
    UIScrollView *sc = [[UIScrollView alloc] initWithFrame:s.view.bounds];
    [s.view addSubview:sc];
    PGConfig *c = [PGConfig shared];

    NSArray *fields = @[
        @{@"key":@"baseURL", @"label":@"Base URL (OpenAI 兼容)", @"val":c.baseURL},
        @{@"key":@"apiKey",  @"label":@"API Key", @"val":c.apiKey},
        @{@"key":@"model",   @"label":@"文本模型", @"val":c.model},
        @{@"key":@"vision",  @"label":@"视觉模型", @"val":c.visionModel}
    ];
    NSMutableArray *tfs = [NSMutableArray array];
    CGFloat y = 30;
    for (NSDictionary *f in fields) {
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w - 40, 20)];
        l.text = f[@"label"]; l.font = [UIFont systemFontOfSize:13]; l.textColor = [UIColor secondaryLabelColor];
        [sc addSubview:l]; y += 24;
        UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(20, y, w - 40, 40)];
        tf.text = f[@"val"]; tf.borderStyle = UITextBorderStyleRoundedRect;
        tf.font = [UIFont systemFontOfSize:14];
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
        tf.tag = tfs.count;
        if ([f[@"key"] isEqualToString:@"apiKey"]) tf.secureTextEntry = YES;
        [sc addSubview:tf]; [tfs addObject:tf]; y += 52;
    }
    // 步数上限
    UILabel *bl = [[UILabel alloc] initWithFrame:CGRectMake(20, y, w - 40, 20)];
    bl.text = @"步数上限"; bl.font = [UIFont systemFontOfSize:13]; bl.textColor = [UIColor secondaryLabelColor];
    [sc addSubview:bl]; y += 24;
    UITextField *budget = [[UITextField alloc] initWithFrame:CGRectMake(20, y, w - 40, 40)];
    budget.text = [NSString stringWithFormat:@"%ld", (long)c.stepBudget];
    budget.borderStyle = UITextBorderStyleRoundedRect; budget.keyboardType = UIKeyboardTypeNumberPad;
    [sc addSubview:budget]; y += 60;

    UIButton *save = [UIButton buttonWithType:UIButtonTypeSystem];
    save.frame = CGRectMake(20, y, w - 40, 44);
    [save setTitle:@"保存" forState:UIControlStateNormal];
    save.backgroundColor = [UIColor systemBlueColor];
    [save setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    save.layer.cornerRadius = 8;
    [save addTarget:self action:@selector(saveSettings:event:) forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(save, "fields", tfs, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(save, "budget", budget, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [sc addSubview:save]; y += 60;
    ((UIScrollView *)sc).contentSize = CGSizeMake(w, y + 40);

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:s];
    s.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        target:self action:@selector(dismissSettings)];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)saveSettings:(UIButton *)btn event:(id)e {
    NSArray *tfs = objc_getAssociatedObject(btn, "fields");
    UITextField *budget = objc_getAssociatedObject(btn, "budget");
    PGConfig *c = [PGConfig shared];
    if (tfs.count >= 4) {
        c.baseURL = ((UITextField *)tfs[0]).text;
        c.apiKey  = ((UITextField *)tfs[1]).text;
        c.model   = ((UITextField *)tfs[2]).text;
        c.visionModel = ((UITextField *)tfs[3]).text;
    }
    c.stepBudget = [budget.text integerValue] ?: 20;
    [c save];
    [self log:@"设置已保存"];
    [self dismissSettings];
}
- (void)dismissSettings { [self dismissViewControllerAnimated:YES completion:nil]; }

#pragma mark - PGAgentDelegate
- (void)agentDidUpdateStatus:(NSString *)status {
    self.statusLabel.text = status;
}
- (void)agentDidAppendLog:(NSString *)line { [self log:line]; }
- (void)agentDidFinish:(NSString *)result success:(BOOL)success {
    self.statusLabel.text = success ? @"完成" : @"结束";
    self.statusLabel.textColor = success ? [UIColor systemGreenColor] : [UIColor systemOrangeColor];
    [self log:[NSString stringWithFormat:@"结果：%@", result]];
}
@end
