//
//  FFGLImage.m
//  VVOpenSource
//
//  Created by Tom on 04/10/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import "FFGLImage.h"


@implementation FFGLImage

- (id)initWithTexture2D:(GLuint)texture imagePixelsWide:(NSUInteger)imageWidth imagePixelsHigh:(NSUInteger)imageHeight texturePixelsWide:(NSUInteger)textureWidth texturePixelsHigh:(NSUInteger)textureHeight releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseContext:(void *)context
{
    if (self = [super init]) {
        _texture2D = texture;
        _imageWidth = imageWidth;
        _imageHeight = imageHeight;
        _texture2DWidth = textureWidth;
        _texture2DHeight = textureHeight;
        _texture2DReleaseCallback = callback;
        _texture2DReleaseContext = context;
    }
    return self;
}

- (void)dealloc {
    if (_texture2DReleaseCallback != NULL) {
        _texture2DReleaseCallback(_texture2D, _texture2DReleaseContext);
    }
    [super dealloc];
}

- (NSUInteger)imagePixelsWide {
    return _imageWidth;
}

- (NSUInteger)imagePixelsHigh {
    return _imageHeight;
}

- (void)lockTexture2DRepresentation {
    // check we have one, generate it if not
    // lock
}

- (void)unlockTexture2DRepresentation {
    // unlock
}

- (GLuint)texture2DName {
    return _texture2D;
}

- (NSUInteger)texture2DPixelsWide {
    return _texture2DWidth;
}

- (NSUInteger)texture2DPixelsHigh {
    return _texture2DHeight;
}
@end
