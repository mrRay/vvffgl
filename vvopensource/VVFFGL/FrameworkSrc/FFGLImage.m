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

#pragma mark Private Callbacks

static void FFGLImageBufferRelease(const void *baseAddress, void* context) {
    // for now, just free the buffer, could make them reusable
    free((void *)baseAddress);
}

// need this to make POT textures of the right size.
static int nextPow2(int a)
{
	// from nehe.gamedev.net lesson 43
	int rval=1;
	while(rval<a) rval<<=1;
	return rval;
}

static void FFGLImageTextureRelease(GLuint name, CGLContextObj cgl_ctx, void *context) {
    CGLLockContext(cgl_ctx);
    glDeleteTextures(1, &name);
    CGLUnlockContext(cgl_ctx);
}

#pragma mark Private Utility

static NSUInteger bytesPerPixelForPixelFormat(NSString *format) {
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
 swapTextureTargets
 Takes pointers to two FFGLTextureInfo structures and performs the TEXTURE_2D <-> TEXTURE_RECTANGLE conversion
 of fromTexture.
 On return toTexture will be filled out with details of a new texture.
 You are responsible for deleting this texture (using glDeleteTextures).
 */
static void swapTextureTargets(CGLContextObj cgl_ctx, FFGLTextureInfo *fromTexture, FFGLTextureInfo *toTexture, GLenum fromTarget)
{		
    CGLLockContext(cgl_ctx);
    
    // cache FBO state
    GLint previousFBO, previousReadFBO, previousDrawFBO;
    
    // the FBO attachment texture we are going to render to.
    GLenum toTarget;
	
    GLsizei width, height;
    // set up our destination target
    if(fromTarget == GL_TEXTURE_RECTANGLE_ARB) {
        toTarget = GL_TEXTURE_2D;
        width = toTexture->hardwareWidth = FFGLPOTDimension(fromTexture->width);
        height = toTexture->hardwareHeight = FFGLPOTDimension(fromTexture->height);
    } else {
        toTarget = GL_TEXTURE_RECTANGLE_ARB;
        width = toTexture->hardwareWidth = fromTexture->width;
        height = toTexture->hardwareHeight = fromTexture->height;
    }
    toTexture->width = fromTexture->width;
    toTexture->height = fromTexture->height;
    /*
     
     Anton -
     
     I'm guessing the width/height stuff below will need some changing to deal with POT textures
     
     */
	
	glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &previousFBO);
	glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &previousReadFBO);
	glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &previousDrawFBO);
	
    
	// new texture
	GLuint newTex;
	glGenTextures(1, &newTex);
        toTexture->texture = newTex;
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
	glBindTexture(fromTarget, fromTexture->texture);
	
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
}

static void *createBufferFromTexture(CGLContextObj cgl_ctx, FFGLTextureInfo *sourceInfo)
{
    // TODO: !
    return NULL;
}


static FFGLTextureInfo *createTextureFromBuffer(CGLContextObj cgl_ctx, void *buffer, NSUInteger pixelsWide, NSUInteger pixelsHigh) // plus pixelFormat, presumably
{
    // TODO: !
    return NULL;
}

@interface FFGLImage (Private)
- (void)releaseResources;
@end

@implementation FFGLImage

/*
 It's kinda big, but helpful to have one designated private initialiser
 */

- (id)initWithCGLContext:(CGLContextObj)context imagePixelsWide:(NSUInteger)imageWidth imagePixelsHigh:(NSUInteger)imageHeight
           texture2DInfo:(FFGLTextureInfo *)texture2DInfo texture2DReleaseCallback:(FFGLImageTextureReleaseCallback)callback2D texture2DReleaseInfo:(void *)releaseInfo2D
         textureRectInfo:(FFGLTextureInfo *)textureRectInfo textureRectReleaseCallback:(FFGLImageTextureReleaseCallback)callbackRect textureRectReleaseInfo:(void *)releaseInfoRect
                  buffer:(const void *)buffer pixelFormat:(NSString *)pixelFormat bufferReleaseCallback:(FFGLImageBufferReleaseCallback)callbackBuffer bufferReleaseInfo:(void *)releaseInfoBuffer
{
    if (self = [super init]) {
        if (imageWidth == 0 || imageHeight == 0) {
            [self release];
            return nil;
        }
        if (pthread_mutex_init(&_conversionLock, NULL) != 0) {
            [self release];
            return nil;
        }
        _context = CGLRetainContext(context);
        _imageWidth = imageWidth;
        _imageHeight = imageHeight;
        if (texture2DInfo != NULL) {
            _texture2DInfo = texture2DInfo;
            _texture2DReleaseCallback = callback2D;
            _texture2DReleaseContext = releaseInfo2D;
            _hasTexture2D = YES;
        }
        if (textureRectInfo != NULL) {
            _textureRectInfo = textureRectInfo;
            _textureRectReleaseCallback = callbackRect;
            _textureRectReleaseContext = releaseInfoRect;
            _hasTextureRect = YES;
        }
        if (buffer != NULL) {
            _buffer = buffer;
            _bufferPixelFormat = [pixelFormat retain];
            _bufferReleaseCallback = callbackBuffer;
            _bufferReleaseContext = releaseInfoBuffer;
            _hasBuffer = YES;
        }
        if (!_hasBuffer && !_hasTexture2D  && !_hasTextureRect) {
            [self release];
            return nil;
        }
    }
    return self;
}
           
- (id)initWithTexture2D:(GLuint)texture CGLContext:(CGLContextObj)context imagePixelsWide:(NSUInteger)imageWidth imagePixelsHigh:(NSUInteger)imageHeight texturePixelsWide:(NSUInteger)textureWidth texturePixelsHigh:(NSUInteger)textureHeight releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseInfo:(void *)userInfo
{
    FFGLTextureInfo *info = malloc(sizeof(FFGLTextureInfo));
    if (info != NULL) {
        info->texture = texture;
        info->width = imageWidth;
        info->height = imageHeight;
        info->hardwareWidth = textureWidth;
        info->hardwareHeight = textureHeight;        
    }
    return [self initWithCGLContext:context imagePixelsWide:imageWidth imagePixelsHigh:imageHeight
                      texture2DInfo:info texture2DReleaseCallback:callback texture2DReleaseInfo:userInfo
                    textureRectInfo:NULL textureRectReleaseCallback:NULL textureRectReleaseInfo:NULL
                             buffer:NULL pixelFormat:nil bufferReleaseCallback:NULL bufferReleaseInfo:NULL];
}

- (id)initWithTextureRect:(GLuint)texture CGLContext:(CGLContextObj)context pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height releaseCallback:(FFGLImageTextureReleaseCallback)callback releaseInfo:(void *)userInfo
{
    FFGLTextureInfo *info = malloc(sizeof(FFGLTextureInfo));
    if (info != NULL) {
        info->texture = texture;
        info->hardwareWidth = _imageWidth = width;
        info->hardwareHeight = _imageHeight = height;
        info->width = width;
        info->height = height;
    }
    return [self initWithCGLContext:context imagePixelsWide:width imagePixelsHigh:height
                      texture2DInfo:NULL texture2DReleaseCallback:NULL texture2DReleaseInfo:NULL
                    textureRectInfo:info textureRectReleaseCallback:callback textureRectReleaseInfo:userInfo
                             buffer:NULL pixelFormat:nil bufferReleaseCallback:NULL bufferReleaseInfo:NULL];
}

- (id)initWithBuffer:(const void *)buffer CGLContext:(CGLContextObj)context pixelFormat:(NSString *)format pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes releaseCallback:(FFGLImageBufferReleaseCallback)callback releaseInfo:(void *)userInfo
{
    // Check the pixel-format is valid
    NSUInteger bpp = bytesPerPixelForPixelFormat(format);
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
        buffer = newBuffer;
        callback = FFGLImageBufferRelease;
        userInfo = NULL;
    }
    return [self initWithCGLContext:context imagePixelsWide:width imagePixelsHigh:height
                      texture2DInfo:NULL texture2DReleaseCallback:NULL texture2DReleaseInfo:NULL
                    textureRectInfo:NULL textureRectReleaseCallback:NULL textureRectReleaseInfo:NULL
                             buffer:buffer pixelFormat:format bufferReleaseCallback:callback bufferReleaseInfo:userInfo];
}

- (void)releaseResources {
    if (_hasTexture2D == YES && _texture2DInfo != NULL) {
        _texture2DReleaseCallback(((FFGLTextureInfo *)_texture2DInfo)->texture, _context, _texture2DReleaseContext);
        free(_texture2DInfo);
    }
    if (_hasTextureRect == YES) {
        _textureRectReleaseCallback(((FFGLTextureInfo *)_textureRectInfo)->texture, _context, _textureRectReleaseContext);
        free(_textureRectInfo);
    }
    if (_hasBuffer == YES) {
        _bufferReleaseCallback(_buffer, _bufferReleaseContext);
    }
    CGLReleaseContext(_context);
    pthread_mutex_destroy(&_conversionLock);
}

- (void)dealloc {
    [self releaseResources];
    [_bufferPixelFormat release];
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
    BOOL result = NO;
    pthread_mutex_lock(&_conversionLock);
    if (_hasTexture2D == YES) {
        result = YES;
    } else {
        if (_hasTextureRect == YES) { // or would we rather check them in the other order?
            _texture2DInfo = malloc(sizeof(FFGLTextureInfo));
            swapTextureTargets(_context, (FFGLTextureInfo *)_textureRectInfo, (FFGLTextureInfo *)_texture2DInfo, GL_TEXTURE_RECTANGLE_ARB);
            if (((FFGLTextureInfo *)_texture2DInfo)->texture == 0) {
                free(_texture2DInfo);
            } else {
                _texture2DReleaseCallback = FFGLImageTextureRelease;
                _texture2DReleaseContext = NULL;
                _hasTexture2D = YES;
                result = YES;
            }
        } else if (_hasBuffer == YES) {
            // TODO: buffer -> texture conversion
            // TODO: result = YES;
        }		
    }
    pthread_mutex_unlock(&_conversionLock);
    return result;
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
    BOOL result = NO;
    pthread_mutex_lock(&_conversionLock);
    if (_hasTextureRect == YES) {
        result = YES;
    } else if (_hasTexture2D) {
        _textureRectInfo = malloc(sizeof(FFGLTextureInfo));
        swapTextureTargets(_context, (FFGLTextureInfo *)_texture2DInfo, (FFGLTextureInfo *)_textureRectInfo, GL_TEXTURE_2D);
        if (((FFGLTextureInfo *)_textureRectInfo)->texture == 0) {
            free(_textureRectInfo);
        } else {
            _textureRectReleaseCallback = FFGLImageTextureRelease;
            _textureRectReleaseContext = NULL;
            _hasTextureRect = YES;
            result = YES;
        }
    } else if (_hasBuffer) {
        // TODO: generate it, return YES;
    }
    pthread_mutex_unlock(&_conversionLock);
    return result;
}

- (void)unlockTextureRectRepresentation {
    // do nothing
}

- (GLuint)textureRectName {
    return ((FFGLTextureInfo *)_textureRectInfo)->texture;
}

- (NSUInteger)textureRectPixelsWide {
    return ((FFGLTextureInfo *)_textureRectInfo)->width;
}

- (NSUInteger)textureRectPixelsHigh {
    return ((FFGLTextureInfo *)_textureRectInfo)->height;
}

#pragma mark Pixel Buffers

- (BOOL)lockBufferRepresentationWithPixelFormat:(NSString *)format {
    BOOL result = NO;
    pthread_mutex_lock(&_conversionLock);
    if (_hasBuffer == YES) {
        if (![format isEqualToString:_bufferPixelFormat]) {
            // We don't support converting between different formats (yet?).
        } else {
            result = YES;
        }
    } else {
        // TODO: Conversion from GL textures.
    }
    pthread_mutex_unlock(&_conversionLock);
    return result;
}

- (void)unlockBufferRepresentation {
    // Do nothing.
}

- (const void *)bufferBaseAddress {
    return _buffer;
}

- (NSUInteger)bufferPixelsWide {
    return _imageWidth;
}

- (NSUInteger)bufferPixelsHigh {
    return _imageHeight;
}

- (NSUInteger)bufferBytesPerRow {
    return _imageWidth * bytesPerPixelForPixelFormat(_bufferPixelFormat);
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
