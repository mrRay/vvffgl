//
//  FFGLImage.h
//  VVOpenSource
//
//  Created by Tom on 04/10/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef void (*FFGLImageTextureReleaseCallback)(GLuint name, void *context);
typedef void (*FFGLImageBufferReleaseCallback)(void *baseAddress, void *context);

@interface FFGLImage : NSObject {
@private
    NSUInteger                      _imageWidth;
    NSUInteger                      _imageHeight;
    GLuint                          _texture2D;
    NSUInteger                      _texture2DWidth;
    NSUInteger                      _texture2DHeight;
    FFGLImageTextureReleaseCallback _texture2DReleaseCallback;
    void                            *_texture2DReleaseContext;
    GLuint                          _textureRect;
    NSUInteger                      _textureRectWidth;
    NSUInteger                      _textureRectHeight;
    FFGLImageTextureReleaseCallback _textureRectReleaseCallback;
    void                            *_textureRectReleaseContext;
    void                            *_buffer;
    NSUInteger                      _bufferWidth;
    NSUInteger                      _bufferHeight;
    NSString                        *_bufferPixelFormat;
    FFGLImageBufferReleaseCallback  _bufferReleaseCallback;
    void                            *_bufferReleaseContext;
}
/*
 Init would look something like this
 is this all the info we need?
 the callback and context allow apps to do what they like with the texture when we're finished with it - destroy it, reuse it or whatever
 Are there any reasonable demands we can make of the texture that would let us drop the texturePixelsWide/High arguments?
 We probably need a CGLContext in here too, yea?
 */
- (id)initWithTexture2D:(GLuint)texture imagePixelsWide:(NSUInteger)imageWidth imagePixelsHigh:(NSUInteger)imageHeight texturePixelsWide:(NSUInteger)textureWidth texturePixelsHigh:(NSUInteger)textureHeight releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseContext:(void *)context;
- (id)initWithTextureRect:(GLuint)texture pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseContext:(void *)context;
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

/*
 and then the same for GL_TEXTURE_RECTANGLE_EXT and pixel buffers, and internal conversion between the types.
 */

- (BOOL)lockTextureRectRepresentation;
- (void)unlockTextureRectRepresentation;
- (GLuint)textureRectName;
- (NSUInteger)textureRectPixelsWide; // or will these just be imagePixelsWide?
- (NSUInteger)textureRectPixelsHigh;

- (BOOL)lockBufferRepresentationWithPixelFormat:(NSString *)format;
- (void)unlockBufferRepresentation;
- (void *)bufferBaseAddress;
- (NSUInteger)bufferPixelsWide; // or will these just be imagePixelsWide?
- (NSUInteger)bufferPixelsHigh;
- (NSUInteger)bufferBytesPerRow;
- (NSString *)bufferPixelFormat;

@end
