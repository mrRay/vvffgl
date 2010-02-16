//
//  FFGLImageRep.h
//  VVFFGL
//
//  Created by Tom on 11/02/2010.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>

/*
 
 FFGLImageRep, FFGLTextureRep, FFGLBufferRep
 
 These are some immutable classes for buffer and texture storage.
 
 They DO NOT perform CGLContext switching or locking, so do that before
 calling any of their init methods.
 
 They ARE NOT thread-safe, so make sure FFGLImage uses them in a thread-
 safe manner - ie from within a lock and without sharing them between images.
 Reading of readonly properties is thread-safe as those properties are immutable.
 
 Some of the copy-at-init methods maintain the flippedness of the source representations where flipping would be costly,
 or fail where copying would be costly. In those cases perform an intermediate conversion to another representation type.
 See the various init methods for more details, or use copyAsType: pixelFormat: inContext: allowingNPOT2D asPrimaryRep:
 which takes care of that for you.
 
 Subscriber count is for external use by FFGLImage to track lock/unlock calls for the representation
 It is at 0 after init
 
 */
typedef NSUInteger FFGLImageRepType;
enum {
    FFGLImageRepTypeTexture2D = 0,
    FFGLImageRepTypeTextureRect = 1,
    FFGLImageRepTypeBuffer = 2
};

@interface FFGLImageRep : NSObject {
@protected
	NSUInteger _subscribers; // we need our own pseudo-retain-count
	BOOL _isPrimary;
	BOOL _isFlipped;
	FFGLImageRepType _type;
}
// Designated initialiser. Subclasses call this.
- (id)initAsType:(FFGLImageRepType)repType isFlipped:(BOOL)flipped asPrimaryRep:(BOOL)isPrimary;

// We expose this as a seperate method so FFGLImage can set and lock the context once for several
// FFGLImageReps, and be certain it is done when the image dies rather than when garbage-collection culls it.
- (void)performCallbackPriorToRelease;
- (NSUInteger)addSubscriber;
- (NSUInteger)removeSubscriber;
- (NSUInteger)subscriptionCount;
@property (readonly) FFGLImageRepType type;
@property (readonly) BOOL isFlipped;
@property (readonly) BOOL isPrimaryRep;
@end

@interface FFGLImageRep (Copying)
// This may create (and destroy) intermediate representations needed to perform the fastest possible copy between types.
- (id)copyAsType:(FFGLImageRepType)type pixelFormat:(NSString *)pixelFormat inContext:(CGLContextObj)context allowingNPOT2D:(BOOL)useNPOT asPrimaryRep:(BOOL)isPrimary;
@end