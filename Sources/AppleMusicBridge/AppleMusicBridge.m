#import "AppleMusicBridge.h"
#import <ScriptingBridge/ScriptingBridge.h>

static NSString * const MusicBridgeErrorDomain = @"AgenticAppleServices.MusicBridge";

// Minimal declarations from Music.app's public SDEF.
// Verify with: sdef /System/Applications/Music.app | sdp -fh --basename Music
@interface MusicItem : SBObject
@property (copy, readonly) NSString *persistentID;
@property (copy) NSString *name;
- (void)playOnce:(BOOL)once;
@end

@interface MusicTrack : MusicItem
@property (copy) NSString *artist;
@property (copy) NSString *album;
@end

@interface MusicApplication : SBApplication
- (SBElementArray<MusicTrack *> *)tracks;
@property (copy, readonly) MusicTrack *currentTrack;
@property (readonly) OSType playerState;
@property double playerPosition;
@property NSInteger soundVolume;
- (void)playOnce:(BOOL)once;
- (void)pause;
- (void)stop;
- (void)nextTrack;
- (void)previousTrack;
@end

@interface AppleMusicBridge () <SBApplicationDelegate>
@property (nonatomic, strong, nullable) NSError *lastEventError;
@end

@implementation AppleMusicBridgeSnapshot
@end

@implementation AppleMusicBridge

- (id)eventDidFail:(const AppleEvent *)event withError:(NSError *)error {
    (void)event;
    self.lastEventError = error;
    return nil;
}

- (NSError *)failure:(NSString *)message code:(NSInteger)code {
    return [NSError errorWithDomain:MusicBridgeErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

- (MusicApplication *)applicationWithError:(NSError **)error {
    MusicApplication *application = (MusicApplication *)
        [SBApplication applicationWithBundleIdentifier:@"com.apple.Music"];
    if (application == nil) {
        if (error != NULL) {
            *error = [self failure:@"Music.app is not scriptable or installed." code:1];
        }
        return nil;
    }
    self.lastEventError = nil;
    application.delegate = self;
    return application;
}

- (BOOL)checkError:(NSError **)error {
    if (self.lastEventError == nil) {
        return YES;
    }
    if (error != NULL) {
        *error = self.lastEventError;
    }
    return NO;
}

- (BOOL)catchException:(NSException *)exception error:(NSError **)error {
    if (error != NULL) {
        *error = [self failure:(exception.reason ?: exception.name) code:2];
    }
    return NO;
}

- (AppleMusicBridgeSnapshot *)snapshotWithError:(NSError **)error {
    MusicApplication *app = [self applicationWithError:error];
    if (app == nil) {
        return nil;
    }
    @try {
        AppleMusicBridgeSnapshot *result = [AppleMusicBridgeSnapshot new];
        OSType state = app.playerState;
        switch (state) {
            case 0x6b505350: result.state = @"playing"; break;
            case 0x6b505370: result.state = @"paused"; break;
            case 0x6b505353: result.state = @"stopped"; break;
            default: result.state = @"other"; break;
        }
        if (![self checkError:error]) {
            return nil;
        }
        result.volume = app.soundVolume;
        if (![self checkError:error]) {
            return nil;
        }
        if (![result.state isEqualToString:@"stopped"]) {
            result.position = app.playerPosition;
            MusicTrack *track = app.currentTrack;
            if (![self checkError:error]) {
                return nil;
            }
            if (track != nil) {
                result.persistentID = track.persistentID;
                result.title = track.name;
                result.artist = track.artist;
                result.album = track.album;
            }
        }
        return [self checkError:error] ? result : nil;
    } @catch (NSException *exception) {
        [self catchException:exception error:error];
        return nil;
    }
}

- (BOOL)playPersistentID:(NSString *)identifier error:(NSError **)error {
    MusicApplication *app = [self applicationWithError:error];
    if (app == nil) {
        return NO;
    }
    @try {
        SBElementArray<MusicTrack *> *tracks = app.tracks;
        NSUInteger count = tracks.count;
        if (![self checkError:error]) {
            return NO;
        }
        NSUInteger maximum = MIN(count, (NSUInteger)50000);
        for (NSUInteger index = 0; index < maximum; index++) {
            MusicTrack *track = tracks[index];
            NSString *value = track.persistentID;
            if (![self checkError:error]) {
                return NO;
            }
            if ([value caseInsensitiveCompare:identifier] == NSOrderedSame) {
                [track playOnce:NO];
                return [self checkError:error];
            }
        }
        if (error != NULL) {
            NSString *message = count > maximum
                ? @"Track not found within bounded Music.app library scan."
                : @"Selected track is not addressable in Music.app.";
            *error = [self failure:message code:3];
        }
        return NO;
    } @catch (NSException *exception) {
        return [self catchException:exception error:error];
    }
}

- (BOOL)control:(NSString *)action error:(NSError **)error {
    MusicApplication *app = [self applicationWithError:error];
    if (app == nil) {
        return NO;
    }
    @try {
        if ([action isEqualToString:@"play"]) {
            [app playOnce:NO];
        } else if ([action isEqualToString:@"pause"]) {
            [app pause];
        } else if ([action isEqualToString:@"stop"]) {
            [app stop];
        } else if ([action isEqualToString:@"next"]) {
            [app nextTrack];
        } else if ([action isEqualToString:@"previous"]) {
            [app previousTrack];
        } else {
            if (error != NULL) {
                *error = [self failure:@"Unknown music control action." code:4];
            }
            return NO;
        }
        return [self checkError:error];
    } @catch (NSException *exception) {
        return [self catchException:exception error:error];
    }
}

- (BOOL)setVolume:(NSInteger)value error:(NSError **)error {
    if (value < 0 || value > 100) {
        if (error != NULL) {
            *error = [self failure:@"Music volume must be in 0...100." code:5];
        }
        return NO;
    }
    MusicApplication *app = [self applicationWithError:error];
    if (app == nil) {
        return NO;
    }
    @try {
        app.soundVolume = value;
        return [self checkError:error];
    } @catch (NSException *exception) {
        return [self catchException:exception error:error];
    }
}

@end
