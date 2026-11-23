//
//  PGLLM.h — OpenAI 兼容视觉模型客户端
//
#import <Foundation/Foundation.h>
#import "PGCommon.h"

@interface PGLLM : NSObject
+ (instancetype)shared;

// 发送任务 + 截图给视觉模型，解析出动作。completion 在主线程回调。
- (void)decideWithTask:(NSString *)task
             screenshot:(NSData *)png
               pointSize:(CGSize)size
              stepIndex:(NSInteger)step
                 history:(NSArray<NSString *> *)history
              completion:(void (^)(PGAction *action, NSString *rawText, NSError *error))completion;

// 纯文本调用（用于总结结果）
- (void)summarize:(NSString *)prompt completion:(void (^)(NSString *text, NSError *error))completion;
@end
