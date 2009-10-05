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

- (id)initWithTextureRect:(GLuint)texture pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseContext:(void *)context {
    if (self = [super init]) {
        // TODO
    }
    return self;
}

- (id)initWithBuffer:(void *)buffer pixelFormat:(NSString *)format pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes releaseCallback:(FFGLImageBufferReleaseCallback)callback releaseContext:(void *)context {
    if (self = [super init]) {
        _buffer = buffer;
        _bufferPixelFormat = [format retain];
        _bufferWidth = _imageWidth = width;
        _bufferHeight = _imageHeight = height;
        // should check rowBytes is valid for pixelsWide and format, and fail or deal with it if not
        _bufferReleaseCallback = callback;
        _bufferReleaseContext = context;
    }
    return self;
}

- (void)dealloc {
    if (_texture2DReleaseCallback != NULL) {
        _texture2DReleaseCallback(_texture2D, _texture2DReleaseContext);
    }
    // release other types if neccessary
    [super dealloc];
}

- (void)finalize {
    if (_texture2DReleaseCallback != NULL) {
        _texture2DReleaseCallback(_texture2D, _texture2DReleaseContext);
    }
    // release other types if neccessary
    [super finalize];
}

- (NSUInteger)imagePixelsWide {
    return _imageWidth;
}

- (NSUInteger)imagePixelsHigh {
    return _imageHeight;
}

- (BOOL)lockTexture2DRepresentation {
    // check we have one, generate it if not
    // lock
    return NO; // return yes once we've implemented this ;)
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

- (BOOL)lockTextureRectRepresentation {
    return NO;
}

- (void)unlockTextureRectRepresentation {
    
}

- (GLuint)textureRectName {
    return _textureRect;
}

- (NSUInteger)textureRectPixelsWide {
    return _textureRectWidth;
}

- (NSUInteger)textureRectPixelsHigh {
    return _textureRectHeight;
}

- (BOOL)lockBufferRepresentationWithPixelFormat:(NSString *)format {
    // TODO: 
    return NO;
}

- (void)unlockBufferRepresentation {
    // TODO: 
}

- (void *)bufferBaseAddress {
    return _buffer;
}

- (NSUInteger)bufferPixelsWide {
    return _bufferWidth;
}

- (NSUInteger)bufferPixelsHigh {
    return _bufferHeight;
}

- (NSUInteger)bufferBytesPerRow {
    // TODO:
}

- (NSString *)bufferPixelFormat {
    return _bufferPixelFormat;
}

/*
 
 The following is copied and pasted from FFGLGPURenderer, needs a little tweaking for use here.
 
 This from init, but shouldn't go in FFGLImage's init, as it's possible it won't be used in lifetime of an image
 */
 /*
 // make the rect to 2D texture FBO.
 CGLLockContext(cgl_ctx);
 
 glGenTextures(1, &_squareFBOTexture);
 glBindTexture(GL_TEXTURE_2D, _squareFBOTexture);
 
 // NOTE: we get the size from our viewport struct. So, we may end making temp textures rather than keeping one around.
 glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, bounds.size.width, bounds.size.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
 
 // cache previous FBO.
 glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &_previousFBO);
 
 // Create temporary FBO to render in texture 
 glGenFramebuffersEXT(1, &_rectToSquareFBO);
 glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _rectToSquareFBO);
 glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, _squareFBOTexture, 0);
 
 GLenum status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
 if(status != GL_FRAMEBUFFER_COMPLETE_EXT)
 {	
 glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _previousFBO);
 glDeleteFramebuffersEXT(1, &_rectToSquareFBO);
 glDeleteTextures(1, &_squareFBOTexture);
 
 CGLUnlockContext(cgl_ctx);
 NSLog(@"Cannot create FFGL FBO");
 return nil;
 }	
 
 // looks like everything worked... cleanup!
 glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _previousFBO);
 CGLUnlockContext(cgl_ctx);
 */

/*	
- (GLuint) rectTextureToSquareTexture:(GLuint)inputTexture withCoords:(NSRect) rectCoords
{    
	// do we necessarily need to re-cache our previous FBO every frame? 
    // // Have moved that out of rendering, so it only happens when input changes... but you need as many square textures as there are inputs, not neccessarily one.
	// do we even need that iVar at all, should that be handled outside of the framework?
    
	// also, do we want to/need to generate a new texture attachment every frame? \
	// that may be required for changing input image dimensions
    
	// we also will probably need to round to the nearest power of two for the texture dimensions and viewport dimensions.
	// argh. JUST. FUCKING. SUPPORT. RECT. TEXTURES. PLEASE.

     CGLContextObj cgl_ctx = _context;
     NSRect viewport = [self bounds];
     glPushAttrib(GL_COLOR_BUFFER_BIT | GL_TRANSFORM_BIT | GL_VIEWPORT_BIT);
     
     // bind our FBO
     glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _rectToSquareFBO);
     
     // set the viewport to the size of our input viewport...
     glViewport(0, 0,  viewport.size.width, viewport.size.height);
     glMatrixMode(GL_PROJECTION);
     glPushMatrix();
     glLoadIdentity();
     
     glOrtho(0.0, viewport.size.width,  0.0,  viewport.size.width, -1, 1);		
     
     glMatrixMode(GL_MODELVIEW);
     glPushMatrix();
     glLoadIdentity();
     
     // this may not be necessary if we use GL_REPLACE for texturing the entire quad.
     glClearColor(0.0, 0.0, 0.0, 0.0);
     glClear(GL_COLOR_BUFFER_BIT);		
     
     // attach our rect texture and draw it the entire size of the viewport, with the proper rect coords.
     glBegin(GL_QUADS);
     glTexCoord2f(0, 0);
     glVertex2f(0, 0);
     glTexCoord2f(0, rectCoords.size.height);
     glVertex2f(0, viewport.size.height);
     glTexCoord2f(rectCoords.size.width, rectCoords.size.height);
     glVertex2f(viewport.size.width, viewport.size.height);
     glTexCoord2f(rectCoords.size.width, 0);
     glVertex2f(viewport.size.width, 0);
     glEnd();		
     
     // Restore OpenGL states 
     glMatrixMode(GL_MODELVIEW);
     glPopMatrix();
     glMatrixMode(GL_PROJECTION);
     glPopMatrix();
     
     // restore states // assume this is balanced with above 
     glPopAttrib();
     
     // restore previous FBO
     // TODO: bug?:
     // We're using the value which we got at init, but isn't that likely to have changed? Shouldn't we inspect and restore every time?
     glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, _previousFBO);
     
     // we need to flush to make sure FBO Texture attachment is rendered
     glFlushRenderAPPLE();
     
     // our input rect texture should now be represented in the returned texture below.

	return _squareFBOTexture;
}
*/
@end
