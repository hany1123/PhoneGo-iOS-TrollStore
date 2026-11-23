//
//  PGAppDelegate.m
//
#import "PGAppDelegate.h"
#import "PGRootViewController.h"
#import "PGCommon.h"

@implementation PGAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    PGRootViewController *root = [[PGRootViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    PGLog("PhoneGo 启动完成");
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // 任务运行时 App 需回前台截图；保持简单，不做后台长期运行（巨魔不支持 launch daemon）。
}
@end
