#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AppleMusicBridgeSnapshot : NSObject
@property (nonatomic, copy) NSString *state;
@property (nonatomic, copy, nullable) NSString *persistentID;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *artist;
@property (nonatomic, copy, nullable) NSString *album;
@property (nonatomic) double position;
@property (nonatomic) NSInteger volume;
@end

@interface AppleMusicBridge : NSObject
- (nullable AppleMusicBridgeSnapshot *)snapshotWithError:(NSError **)error;
- (BOOL)playPersistentID:(NSString *)identifier error:(NSError **)error;
- (BOOL)control:(NSString *)action error:(NSError **)error;
- (BOOL)setVolume:(NSInteger)value error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
