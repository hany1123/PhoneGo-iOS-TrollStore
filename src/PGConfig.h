//
//  PGConfig.h — 设置持久化
//
#import <Foundation/Foundation.h>

@interface PGConfig : NSObject
+ (instancetype)shared;
@property (nonatomic, copy) NSString *baseURL;
@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy) NSString *model;
@property (nonatomic, copy) NSString *visionModel;
@property (nonatomic, assign) NSInteger stepBudget;
@property (nonatomic, assign) NSInteger maxTokens;
- (void)save;
- (BOOL)isConfigured;
@end
