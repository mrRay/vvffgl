//
//  FFGLImage.m
//  VVOpenSource
//
//  Created by Tom on 04/10/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import "FFGLImage.h"
#import "FFGLPlugin.h"
#import "FFGLInternal.h"
//#import <libkern/OSAtomic.h>

enum FFGLImageSource {
    FFGLImageSourceTexture2D,
    FFGLImageSourceTextureRect,
    FFGLImageSourceBuffer
};

static void FFGLImageBufferRelease(void *baseAddress, void* context) {
    // for now, just free the buffer, could make them reusable
    free(baseAddress);
}

static GLuint swapTextureTargets(CGLContextObj cgl_ctx, GLuint textureName, GLsizei width, GLsizei height, GLenum fromTarget)
{		
	CGLLockContext(cgl_ctx);
	
	// cache FBO state
	GLint previousFBO, previousReadFBO, previousDrawFBO;
	
	// the FBO attachment texture we are going to render to.
	GLenum toTarget;
	
	// set up our destination target
	if(fromTarget == GL_TEXTURE_RECTANGLE_ARB)
		toTarget = GL_TEXTURE_2D;
	else 
		toTarget = GL_TEXTURE_RECTANGLE_ARB;

	
	glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &previousFBO);
	glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &previousReadFBO);
	glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &previousDrawFBO);
	
	// new texture
	GLuint newTex;
	glGenTextures(1, &newTex);
	glBindTexture(toTarget, newTex);
	glTexImage2D(toTarget, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	
	// make new FBO and attach.
	GLuint fboID;
	glGenFramebuffersEXT(1, &fboID);
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, fboID);
	glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, toTarget, newTex, 0);
	
	// draw ofTexture into new texture;
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	
	glViewport(0, 0, width, height);
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	
	// weirdo ortho
	glOrtho(0.0, width, height, 0.0, -1, 1);		
	
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();
	
	// draw the texture.
	//texture->draw(0,0);
	
	glEnable(fromTarget);
	glBindTexture(fromTarget, textureName);
	
	if(fromTarget == GL_TEXTURE_RECTANGLE_ARB)
	{	
		glBegin(GL_QUADS);
		glTexCoord2f(0, 0);
		glVertex2f(0, 0);
		glTexCoord2f(0, height);
		glVertex2f(0, height);
		glTexCoord2f(width, height);
		glVertex2f(width, height);
		glTexCoord2f(width, 0);
		glVertex2f(width, 0);
		glEnd();		
	}
	else if(fromTarget == GL_TEXTURE_2D)
	{
		glBegin(GL_QUADS);
		glTexCoord2f(0, 0);
		glVertex2f(0, 0);
		glTexCoord2f(0, 1);
		glVertex2f(0, height);
		glTexCoord2f(1, 1);
		glVertex2f(width, height);
		glTexCoord2f(1, 0);
		glVertex2f(width, 0);
		glEnd();		
	}
	else
	{
		// uh....
	}
	
	glBindTexture(fromTarget, 0);
	glDisable(fromTarget);
	
	// Restore OpenGL states 
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
	
	// restore states // assume this is balanced with above 
	glPopAttrib();
	
	// pop back to old FBO
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, previousFBO);	
	glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, previousReadFBO);
	glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, previousDrawFBO);
	
	glFlushRenderAPPLE();
	
	// delete our FBO so we dont leak.
	glDeleteFramebuffersEXT(1, &fboID);
	
	CGLUnlockContext(cgl_ctx);
	
	return newTex;
}


@interface FFGLImage (Private)
- (void)releaseResources;
- (NSUInteger)bytesPerPixelForPixelFormat:(NSString *)format;
@end

@implementation FFGLImage

- (id)initWithTexture2D:(GLuint)texture CGLContext:(CGLContextObj)context imagePixelsWide:(NSUInteger)imageWidth imagePixelsHigh:(NSUInteger)imageHeight texturePixelsWide:(NSUInteger)textureWidth texturePixelsHigh:(NSUInteger)textureHeight releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseInfo:(void *)userInfo
{
    if (self = [super init]) {
        _texture2DInfo = malloc(sizeof(FFGLTextureInfo));
        if (_texture2DInfo == NULL) {
            [self release];
            return nil;
        }
        _context = CGLRetainContext(context);
        _source = FFGLImageSourceTexture2D;
        ((FFGLTextureInfo *)_texture2DInfo)->texture = texture;
        ((FFGLTextureInfo *)_texture2DInfo)->width = _imageWidth = imageWidth;
        ((FFGLTextureInfo *)_texture2DInfo)->height = _imageHeight = imageHeight;
        ((FFGLTextureInfo *)_texture2DInfo)->hardwareWidth = textureWidth;
        ((FFGLTextureInfo *)_texture2DInfo)->hardwareHeight = textureHeight;
        _texture2DReleaseCallback = callback;
        _texture2DReleaseContext = userInfo;
        _hasTexture2D = YES;
    }
    return self;
}

- (id)initWithTextureRect:(GLuint)texture CGLContext:(CGLContextObj)context pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseInfo:(void *)userInfo {
    if (self = [super init]) {
        _context = CGLRetainContext(context);
        _source = FFGLImageSourceTextureRect;
        _textureRect = texture;
        _textureRectWidth = _imageWidth = width;
        _textureRectHeight = _imageHeight = height;
        _textureRectReleaseCallback = callback;
        _textureRectReleaseContext = userInfo;
        _hasTextureRect = YES;
    }
    return self;
}

- (id)initWithBuffer:(void *)buffer CGLContext:(CGLContextObj)context pixelFormat:(NSString *)format pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes releaseCallback:(FFGLImageBufferReleaseCallback)callback releaseInfo:(void *)userInfo {
    if (self = [super init]) {
        _context = CGLRetainContext(context);
        _source = FFGLImageSourceBuffer;
        _hasBuffer = YES;
        _bufferPixelFormat = [format retain];
        _imageWidth = width;
        _imageHeight = height;
        // Check the pixel-format is valid
        NSUInteger bpp = [self bytesPerPixelForPixelFormat:format];
        if (bpp == 0) { 
            [NSException raise:@"FFGLImageException" format:@"Invalid pixel-format."];
            [self release];
            return nil;
        }
        if ((width * bpp) != rowBytes) {
            // FF plugins don't support pixel buffers where image width != row width.
            // We could just fiddle the reported image width, but this would give wrong results if the plugin takes borders into account.
            // In these cases we make a new buffer with no padding.
            void *newBuffer = valloc(width * bpp * height);
            if (newBuffer == NULL) {
                [self release];
                return nil;
            }
            NSUInteger i;
            for (i = 0; i < height; i++) {
                memcpy(newBuffer, buffer, width * bpp);
            }
            if (callback != NULL) {
                callback(buffer, context);
            }
            _buffer = newBuffer;
            _bufferReleaseCallback = FFGLImageBufferRelease;
            _bufferReleaseContext = NULL;
        } else {
            _buffer = buffer;
            _bufferReleaseCallback = callback;
            _bufferReleaseContext = userInfo;
        }
    }
    return self;
}

- (void)releaseResources {
    if (_hasTexture2D == YES && _texture2DInfo != NULL) {
        _texture2DReleaseCallback(((FFGLTextureInfo *)_texture2DInfo)->texture, _context, _texture2DReleaseContext);
        free(_texture2DInfo);
    }
    if (_hasTextureRect == YES) {
        _textureRectReleaseCallback(_textureRect, _context, _textureRectReleaseContext);
    }
    if (_hasBuffer == YES) {
        _bufferReleaseCallback(_buffer, _bufferReleaseContext);
    }
    CGLReleaseContext(_context);
}

- (void)dealloc {
    [self releaseResources];
    [super dealloc];
}

- (void)finalize {
    [self releaseResources];
    [super finalize];
}

- (NSUInteger)imagePixelsWide {
    return _imageWidth;
}

- (NSUInteger)imagePixelsHigh {
    return _imageHeight;
}

#pragma mark GL_TEXTURE_2D

- (BOOL)lockTexture2DRepresentation {
    if (_hasTexture2D == YES) {
        return YES;
    } else {
        if (_hasTextureRect == YES) { // or would we rather check them in the other order?
            
        } else if (_hasBuffer == YES) {
            
        } else {
            // huh?
        }
        // TODO: generate it, return YES;
		
		
    }
    return NO;
}

- (void)unlockTexture2DRepresentation {
    // do nothing
}

- (GLuint)texture2DName {
    return ((FFGLTextureInfo *)_texture2DInfo)->texture;
}

- (NSUInteger)texture2DPixelsWide {
    return ((FFGLTextureInfo *)_texture2DInfo)->hardwareWidth;
}

- (NSUInteger)texture2DPixelsHigh {
    return ((FFGLTextureInfo *)_texture2DInfo)->hardwareHeight;
}

- (FFGLTextureInfo *)_texture2DInfo {
    return _texture2DInfo;
}

#pragma mark GL_TEXTURE_RECTANGLE_EXT

- (BOOL)lockTextureRectRepresentation {
    if (_hasTextureRect == YES) {
        return YES;
    } else {
		
		
        // TODO: generate it, return YES;
    }
    return NO;
}

- (void)unlockTextureRectRepresentation {
    // do nothing
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

#pragma mark Pixel Buffers

- (BOOL)lockBufferRepresentationWithPixelFormat:(NSString *)format {
    if (_hasBuffer == YES) {
        if (![format isEqualToString:_bufferPixelFormat]) {
            // We don't support converting between different formats (yet?).
            return NO;
        } else {
            return YES;
        }
    } else {
        // TODO: Conversion from GL textures.
    }
    return NO;
}

- (void)unlockBufferRepresentation {
    // Do nothing.
}

- (void *)bufferBaseAddress {
    return _buffer;
}

- (NSUInteger)bufferPixelsWide {
    return _imageWidth;
}

- (NSUInteger)bufferPixelsHigh {
    return _imageHeight;
}

- (NSUInteger)bufferBytesPerRow {
    return _imageWidth * [self bytesPerPixelForPixelFormat:_bufferPixelFormat];
}

- (NSString *)bufferPixelFormat {
    return _bufferPixelFormat;
}

#pragma mark Utility

- (NSUInteger)bytesPerPixelForPixelFormat:(NSString *)format {
    if ([format isEqualToString:FFGLPixelFormatRGB565] || [format isEqualToString:FFGLPixelFormatBGR565]) {
        return 2;
    } else if ([format isEqualToString:FFGLPixelFormatRGB888] || [format isEqualToString:FFGLPixelFormatBGR888]) {
        return 3;
    } else if ([format isEqualToString:FFGLPixelFormatARGB8888] || [format isEqualToString:FFGLPixelFormatBGRA8888]) {
        return 4;
    } else {
        return 0;
    }
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
