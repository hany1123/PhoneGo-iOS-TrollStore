//
//  main.m — PhoneGo iOS 入口（含顶层异常捕获，防止未捕获异常直接闪退）
//
#import <UIKit/UIKit.h>
#import "PGAppDelegate.h"

static void PGUncaughtExceptionHandler(NSException *exception) {
    NSString *reason = [NSString stringWithFormat:@"%@\n%@\n%@",
        exception.name, exception.reason, [exception.callStackSymbols componentsJoinedByString:@"\n"]];
    NSLog(@"[PhoneGo] 未捕获异常: %@", reason);
    // 写到文档目录，便于真机排查（无沙盒下也可通过文件 App 访问）
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count) {
        NSString *log = [paths[0] stringByAppendingPathComponent:@"crash.log"];
        [[reason stringByAppendingString:@"\n"] writeToFile:log atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

int main(int argc, char * argv[]) {
    @autoreleasepool {
        NSSetUncaughtExceptionHandler(&PGUncaughtExceptionHandler);
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([PGAppDelegate class]));
    }
}
