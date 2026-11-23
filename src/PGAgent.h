//
//  PGAgent.h — Agent 循环引擎
//
#import <Foundation/Foundation.h>

@protocol PGAgentDelegate <NSObject>
- (void)agentDidUpdateStatus:(NSString *)status;
- (void)agentDidAppendLog:(NSString *)line;
- (void)agentDidFinish:(NSString *)result success:(BOOL)success;
@end

@interface PGAgent : NSObject
+ (instancetype)shared;
@property (nonatomic, weak) id<PGAgentDelegate> delegate;
@property (nonatomic, assign, readonly) BOOL running;
- (void)runTask:(NSString *)task;
- (void)stop;
@end
