//
//  FFGLImage.h
//  VVOpenSource
//
//  Created by Tom on 04/10/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <pthread.h>

typedef void (*FFGLImageTextureReleaseCallback)(GLuint name, CGLContextObj cgl_ctx, void *context);
typedef void (*FFGLImageBufferReleaseCallback)(const void *baseAddress, void *context);

@interface FFGLImage : NSObject {
@private
    BOOL                            _hasBuffer;
    BOOL                            _hasTexture2D;
    BOOL                            _hasTextureRect;
    NSUInteger                      _imageWidth;
    NSUInteger                      _imageHeight;
    CGLContextObj                   _context;
    pthread_mutex_t                 _conversionLock;
    void                            *_texture2DInfo;
    FFGLImageTextureReleaseCallback _texture2DReleaseCallback;
    void                            *_texture2DReleaseContext;
    void                            *_textureRectInfo;
    FFGLImageTextureReleaseCallback _textureRectReleaseCallback;
    void                            *_textureRectReleaseContext;
    const void                      *_buffer;
    NSString                        *_bufferPixelFormat;
    FFGLImageBufferReleaseCallback  _bufferReleaseCallback;
    void                            *_bufferReleaseContext;
}

/*
    unlockXXRepresentation currently does nothing. This means we keep all our resources around until dealloc. Releasing textures/buffers on unlock would require either
        - that we stipulate one lock, one unlock call (which is difficult for clients and us because you don't know what other objects hold
            references to the image and may have locked it too).
    or  - that lock/unlock perform something akin to retain-counting, and that we stipulate that calls be matched (each lock has an unlock).
 */

/*

 */
- (id)initWithTexture2D:(GLuint)texture CGLContext:(CGLContextObj)context imagePixelsWide:(NSUInteger)imageWidth imagePixelsHigh:(NSUInteger)imageHeight texturePixelsWide:(NSUInteger)textureWidth texturePixelsHigh:(NSUInteger)textureHeight releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseInfo:(void *)userInfo;

- (id)initWithTextureRect:(GLuint)texture CGLContext:(CGLContextObj)context pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseInfo:(void *)userInfo;

/*
 - (id)initWithBuffer:(void *)buffer pixelFormat:(NSString *)format pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes releaseCallback:(FFGLImageBufferReleaseCallback)callback releaseInfo:(void *)userInfo
    Creates a new FFGLImage with the provided buffer. The buffer should remain valid until the function at callback is called.
    Note that due to limitations in FreeFrame plugins, if there are padding pixels in the buffer (ie if rowBytes != ((the number of bytes per pixel for format) * width)),
    the buffer will be copied at init. In this case the function provided in callback will be called immediately.
 */
- (id)initWithBuffer:(const void *)buffer CGLContext:(CGLContextObj)context pixelFormat:(NSString *)format pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes releaseCallback:(FFGLImageBufferReleaseCallback)callback releaseInfo:(void *)userInfo;


/*
 - (id)initWithCopiedTextureRect:(GLuint)texture CGLContext:(CGLContextObj)context pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height
    Copies texture to a new texture.
 */
- (id)initWithCopiedTextureRect:(GLuint)texture CGLContext:(CGLContextObj)context pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height;

- (NSUInteger)imagePixelsWide;
- (NSUInteger)imagePixelsHigh;

/*
 lockTexture2DRepresentation
    Creates a GL_TEXTURE_2D representation of the image if none already exists. This will remain valid until a call to unlockTexture2DRepresentation.
 */
- (BOOL)lockTexture2DRepresentation;
- (void)unlockTexture2DRepresentation;
/*
 Do not call the following until a call to lockTexture2DRepresentation has returned
 */
- (GLuint)texture2DName;
- (NSUInteger)texture2DPixelsWide;
- (NSUInteger)texture2DPixelsHigh;

- (BOOL)lockTextureRectRepresentation;
- (void)unlockTextureRectRepresentation;
/*
 Do not call the following until a call to lockTextureRectRepresentation has returned
 */
- (GLuint)textureRectName;
- (NSUInteger)textureRectPixelsWide;
- (NSUInteger)textureRectPixelsHigh;

/*
 - (BOOL)lockBufferRepresentationWithPixelFormat:(NSString *)format
    Creates a buffer representation of the image if none already exists. This will remain valid until a call to unlockBufferRepresentation.
    Returns YES if a buffer representation exists or was created, NO otherwise. You should check the returned value before attempting to use the buffer.
    Note that this will fail (return NO) if you attempt to lock a buffer representation when one is already locked in another format, or if the FFGLImage
    was created from a buffer in another format, or if a buffer in the requested format could not be created from an existing texture representation, or
    for other reasons.
 */
- (BOOL)lockBufferRepresentationWithPixelFormat:(NSString *)format;
- (void)unlockBufferRepresentation;
/*
 Do not call the following until a call to lockBufferRepresentationWithPixelFormat: has returned
 */
- (const void *)bufferBaseAddress;
- (NSUInteger)bufferPixelsWide;
- (NSUInteger)bufferPixelsHigh;
- (NSUInteger)bufferBytesPerRow;
- (NSString *)bufferPixelFormat;

@end
