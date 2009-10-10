//
//  FFGLImage.h
//  VVOpenSource
//
//  Created by Tom on 04/10/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <pthread.h>

typedef void (*FFGLImageTextureReleaseCallback)(GLuint name, void *context);
typedef void (*FFGLImageBufferReleaseCallback)(void *baseAddress, void *context);

@interface FFGLImage : NSObject {
@private
    NSUInteger                      _source; // we maybe don't need to track this
    BOOL                            _hasBuffer;
    BOOL                            _hasTexture2D;
    BOOL                            _hasTextureRect;
    NSUInteger                      _imageWidth;
    NSUInteger                      _imageHeight;
    pthread_mutex_t                 _conversionLock;
    void                            *_texture2DInfo;
    FFGLImageTextureReleaseCallback _texture2DReleaseCallback;
    void                            *_texture2DReleaseContext;
    GLuint                          _textureRect;
    NSUInteger                      _textureRectWidth;
    NSUInteger                      _textureRectHeight;
    FFGLImageTextureReleaseCallback _textureRectReleaseCallback;
    void                            *_textureRectReleaseContext;
    void                            *_buffer;
    NSString                        *_bufferPixelFormat;
    FFGLImageBufferReleaseCallback  _bufferReleaseCallback;
    void                            *_bufferReleaseContext;
}
/*
 Resource use
 
    Currently we do nothing when an unlockBuffer../unlockTexture.. call is made, and keep the created buffer/texture around until dealloc.
    That seem an OK thing to do?
 
 */

/*
 
 Locking
    We're going to have to lock when we convert textures<->pixel-buffers, so we don't perform the conversions twice
 */

/*
 Init would look something like this
 is this all the info we need?
 the callback and context allow apps to do what they like with the texture when we're finished with it - destroy it, reuse it or whatever
 Are there any reasonable demands we can make of the texture that would let us drop the texturePixelsWide/High arguments?
 We probably need a CGLContext in here too, yea?
 */
- (id)initWithTexture2D:(GLuint)texture imagePixelsWide:(NSUInteger)imageWidth imagePixelsHigh:(NSUInteger)imageHeight texturePixelsWide:(NSUInteger)textureWidth texturePixelsHigh:(NSUInteger)textureHeight releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseContext:(void *)context;

/*
 Do we need texture pixel size as well as image size, or are there no restrictings on GL_TEXTURE_RECTANGLE_EXT dimensions?
 */
- (id)initWithTextureRect:(GLuint)texture pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseContext:(void *)context;

/*
 - (id)initWithBuffer:(void *)buffer pixelFormat:(NSString *)format pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes releaseCallback:(FFGLImageBufferReleaseCallback)callback releaseContext:(void *)context
    Creates a new FFGLImage with the provided buffer. The buffer should remain valid until the function at callback is called.
    Note that due to limitations in FreeFrame plugins, if there are padding pixels in the buffer (ie if rowBytes != ((the number of bytes per pixel for format) * width)),
    the buffer will be copied at init.
 */
- (id)initWithBuffer:(void *)buffer pixelFormat:(NSString *)format pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes releaseCallback:(FFGLImageBufferReleaseCallback)callback releaseContext:(void *)context;

- (NSUInteger)imagePixelsWide;
- (NSUInteger)imagePixelsHigh;

/*
 lockTexture2DRepresentation
    Creates a GL_TEXTURE_2D representation of the image if none already exists. This will remain valid until a call to unlockTexture2DRepresentation.
 */
- (BOOL)lockTexture2DRepresentation;
- (void)unlockTexture2DRepresentation;
- (GLuint)texture2DName;
- (NSUInteger)texture2DPixelsWide;
- (NSUInteger)texture2DPixelsHigh;

- (BOOL)lockTextureRectRepresentation;
- (void)unlockTextureRectRepresentation;
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
- (void *)bufferBaseAddress;
- (NSUInteger)bufferPixelsWide;
- (NSUInteger)bufferPixelsHigh;
- (NSUInteger)bufferBytesPerRow;
- (NSString *)bufferPixelFormat;

@end
