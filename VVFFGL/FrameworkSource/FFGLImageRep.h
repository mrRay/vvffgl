//
//  FFGLImageRep.h
//  VVFFGL
//
//  Created by Tom on 01/02/2010.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import "FFGLImage.h"
#import "FFGLInternal.h"


/*
 FFGLImageRep
 
	These functions are NOT thread-safe. They must be used in a thread-safe manner from FFGLImage.
	No functions for introspection, access the struct members directly.
 */
typedef NSUInteger FFGLImageRepType;
enum {
    FFGLImageRepTypeTexture2D = 0,
    FFGLImageRepTypeTextureRect = 1,
    FFGLImageRepTypeBuffer = 2
};

// FFGLTextureInfo is in FFGLInternal.h as it's shared with plugins.

typedef struct FFGLBufferInfo {
    unsigned int	width;
    unsigned int    height;
    NSString		*pixelFormat;
    const void		*buffer;
} FFGLBufferInfo;

typedef union FFGLImageRepCallback {
    FFGLImageTextureReleaseCallback	textureCallback;
    FFGLImageBufferReleaseCallback	bufferCallback;
} FFGLImageRepCallback;

typedef union FFGLImageRepInfo {
    FFGLBufferInfo	bufferInfo;
    FFGLTextureInfo	textureInfo;
} FFGLImageRepInfo;

typedef struct FFGLImageRep
{
    FFGLImageRepType		type;
    BOOL					flipped;
    FFGLImageRepInfo		repInfo;
    FFGLImageRepCallback    releaseCallback;
    void					*releaseContext;
} FFGLImageRep;

FFGLImageRep *FFGLTextureRepCreateFromTexture(GLint texture, FFGLImageRepType type, NSUInteger imageWidth, NSUInteger imageHeight, NSUInteger textureWidth, NSUInteger textureHeight, BOOL isFlipped, FFGLImageTextureReleaseCallback callback, void *userInfo);
FFGLImageRep *FFGLBufferRepCreateFromBuffer(const void *source, NSUInteger width, NSUInteger height, NSUInteger rowBytes, NSString *pixelFormat, BOOL isFlipped, FFGLImageBufferReleaseCallback callback, void *userInfo, BOOL forceCopy);
FFGLImageRep *FFGLTextureRepCreateFromTextureRep(CGLContextObj cgl_ctx, const FFGLImageRep *fromTextureRep, FFGLImageRepType toTarget, BOOL useNPOT);
FFGLImageRep *FFGLTextureRepCreateFromBufferRep(CGLContextObj cgl_ctx, const FFGLImageRep *fromBufferRep, FFGLImageRepType toTarget, BOOL useNPOT);
FFGLImageRep *FFGLBufferRepCreateFromTextureRep(CGLContextObj cgl_ctx, const FFGLImageRep *fromTextureRep, NSString *pixelFormat);
void FFGLImageRepDestroy(CGLContextObj lockedContext, FFGLImageRep *rep);
