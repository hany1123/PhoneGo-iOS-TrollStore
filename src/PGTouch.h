//
//  PGTouch.h — 全局触摸注入（IOHIDEvent 系统级派发）
//
//  巨魔无沙盒 App 下用 IOHIDEventSystemClientDispatchEvent 把 digitizer 事件
//  派发到当前前台进程，实现跨 App 点击 / 滑动。ABI 移植自已验证的连点器工程。
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PGTouch : NSObject
+ (instancetype)shared;
- (BOOL)channelsReady;                 // 符号是否全部解析成功
- (NSString *)diagnosticInfo;          // 一行诊断，供 UI 显示
- (void)refreshFrontmostContext;       // 刷新前台 App 的 contextId（每步调用）

- (void)tapAt:(CGPoint)point;
- (void)swipeFrom:(CGPoint)from to:(CGPoint)to durationMs:(NSTimeInterval)ms;
- (void)home;                          // 回主屏（按 Home 键）
- (void)cancelAll;                     // 抬起所有按下中的手指（急停）
@end
