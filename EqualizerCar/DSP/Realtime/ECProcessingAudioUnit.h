#import <AVFoundation/AVFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface ECProcessingAudioUnit : AUAudioUnit
+ (void)registerComponents;
- (void)setDSPParameter:(NSUInteger)index value:(float)value;
@end
NS_ASSUME_NONNULL_END
