//
//  FFGLBufferRep.h
//  VVFFGL
//
//  Created by Tom on 11/02/2010.
//

#import <Cocoa/Cocoa.h>
#import "FFGLInternal.h"
#import <OpenGL/OpenGL.h>
#import "FFGLImageRep.h"


@interface FFGLBufferRep : FFGLImageRep {
@private
	const void *_buffer;
	NSUInteger _width;
	NSUInteger _height;
	NSUInteger _rowBytes;
	NSString *_pixelFormat;
	FFGLImageBufferReleaseCallback _callback;
	void *_userInfo;
}
- (id)initWithBuffer:(const void *)source width:(NSUInteger)width height:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes pixelFormat:(NSString *)pixelFormat isFlipped:(BOOL)flipped callback:(FFGLImageBufferReleaseCallback)callback userInfo:(void *)userInfo asPrimaryRep:(BOOL)isPrimary;

/* Buffer -> buffer
 
 Always produces a non-flipped buffer.
 Always produces a buffer where rowBytes has no padding.
 */
- (id)initWithCopiedBuffer:(const void *)source width:(NSUInteger)width height:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes pixelFormat:(NSString *)pixelFormat isFlipped:(BOOL)flipped asPrimaryRep:(BOOL)isPrimary;

/* Texture -> buffer
 
 Retaines the flippedness of the source texture.
 Fails if the texture extends beyond the image bounds.
 */
- (id)initFromNonFlippedTexture:(GLuint)texture ofType:(FFGLImageRepType)type context:(CGLContextObj)cgl_ctx imageWidth:(NSUInteger)width imageHeight:(NSUInteger)height textureWidth:(NSUInteger)textureWidth textureHeight:(NSUInteger)textureHeight toPixelFormat:(NSString *)pixelFormat allowingNPOT:(BOOL)useNPOT asPrimaryRep:(BOOL)isPrimary;

- (id)copyAsType:(FFGLImageRepType)type pixelFormat:(NSString *)pixelFormat inContext:(CGLContextObj)context allowingNPOT2D:(BOOL)useNPOT asPrimaryRep:(BOOL)isPrimary;

@property (readonly) const void *baseAddress;
@property (readonly) NSUInteger imageWidth;
@property (readonly) NSUInteger imageHeight;
@property (readonly) NSUInteger rowBytes;
@property (readonly) NSString *pixelFormat;
@end
