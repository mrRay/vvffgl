//
//  FFGLImage.h
//  VVOpenSource
//
//  Created by Tom on 04/10/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef void (*FFGLImageTextureReleaseCallback)(GLuint name, void* context);

@interface FFGLImage : NSObject {
@private
    GLuint                          _texture2D;
    NSUInteger                      _texture2DWidth;
    NSUInteger                      _texture2DHeight;
    NSUInteger                      _imageWidth;
    NSUInteger                      _imageHeight;
    FFGLImageTextureReleaseCallback _texture2DReleaseCallback;
    void                            *_texture2DReleaseContext;
}
/*
 Init would look something like this
 is this all the info we need?
 the callback and context allow apps to do what they like with the texture when we're finished with it - destroy it, reuse it or whatever
 Are there any reasonable demands we can make of the texture that would let us drop the texturePixelsWide/High arguments?
 We probably need a CGLContext in here too, yea?
 */
- (id)initWithTexture2D:(GLuint)texture imagePixelsWide:(NSUInteger)imageWidth imagePixelsHigh:(NSUInteger)imageHeight texturePixelsWide:(NSUInteger)textureWidth texturePixelsHigh:(NSUInteger)textureHeight releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseContext:(void *)context;

/*
 We could also support
 - (id)initWithTextureRect:(GLuint)texture pixelsWide:(NSUInteger)width pixelsHigh:(CGFloat)height releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseContext:(void *)context;
 */

- (NSUInteger)imagePixelsWide;
- (NSUInteger)imagePixelsHigh;

/*
 lockTexture2DRepresentation
    so it can't be altered while being drawn and vice versa.
    later we can generate it if we convert from pixelbuffers and GL_TEXTURE_RECTANGLE_EXT
 */

- (void)lockTexture2DRepresentation;
- (void)unlockTexture2DRepresentation;
- (GLuint)texture2DName;
- (NSUInteger)texture2DPixelsWide;
- (NSUInteger)texture2DPixelsHigh;

/*
 and then the same for GL_TEXTURE_RECTANGLE_EXT and pixel buffers, and internal conversion between the types.
 */
@end
