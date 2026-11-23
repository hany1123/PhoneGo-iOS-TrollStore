//
//  PGScreen.h — 全局截屏
//
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PGScreen : NSObject
+ (instancetype)shared;
// 截取整个屏幕（含前台其他 App），返回 PNG data。pointSize 为输出的逻辑坐标尺寸。
- (NSData *)capturePNG:(CGSize *)outPointSize;
- (NSString *)diagnosticInfo;
@end
