//
//  FFGLTextureRep.h
//  VVFFGL
//
//  Created by Tom on 11/02/2010.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import "FFGLInternal.h"
#import "FFGLImageRep.h"
#import "FFGLImage.h"

@interface FFGLTextureRep : FFGLImageRep <NSCopying> {
@private
	CGLContextObj _context;
	FFGLTextureInfo _textureInfo;
	FFGLImageTextureReleaseCallback _callback;
	void *_userInfo;
}
- (id)initWithTexture:(GLint)texture context:(CGLContextObj)context ofType:(FFGLImageRepType)type imageWidth:(NSUInteger)imageWidth imageHeight:(NSUInteger)imageHeight textureWidth:(NSUInteger)textureWidth textureHeight:(NSUInteger)textureHeight isFlipped:(BOOL)flipped callback:(FFGLImageTextureReleaseCallback)callback userInfo:(void *)userInfo asPrimaryRep:(BOOL)isPrimary;

/* Texture -> texture

 Always produces a non-flipped texture. Won't fail unless for GL errors.
 
 */
- (id)initCopyingTexture:(GLint)texture ofType:(FFGLImageRepType)fromType context:(CGLContextObj)context imageWidth:(NSUInteger)imageWidth imageHeight:(NSUInteger)imageHeight textureWidth:(NSUInteger)fromTextureWidth textureHeight:(NSUInteger)fromTextureHeight isFlipped:(BOOL)flipped toType:(FFGLImageRepType)toType allowingNPOT:(BOOL)useNPOT asPrimaryRep:(BOOL)isPrimary;


/* Buffer -> texture
 
 Maintains the flippedness of the source.
 To produce a flipped texture, use initCopyingTexture... with the result of this.
 The texture uses the supplied buffer for its lifetime, and so the buffer must exist for the lifetime of the FFGLTextureRep

 Fails if all the following are true: toType is FFGLImageRepTypeTexture2D, useNPOT is NO, and width or height is not a POT number.
 If that is the case, create a FFGLImageRepTypeTextureRect representation, then use initCopyingTexture... with the result of this
 
 */
- (id)initFromBuffer:(const void *)buffer context:(CGLContextObj)cgl_ctx width:(NSUInteger)width height:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes pixelFormat:(NSString *)pixelFormat isFlipped:(BOOL)flipped toType:(FFGLImageRepType)toType allowingNPOT:(BOOL)useNPOT asPrimaryRep:(BOOL)isPrimary;

- (id)copyAsType:(FFGLImageRepType)type pixelFormat:(NSString *)pixelFormat inContext:(CGLContextObj)context allowingNPOT2D:(BOOL)useNPOT asPrimaryRep:(BOOL)isPrimary;

@property (readonly) FFGLTextureInfo *textureInfo;
@end
