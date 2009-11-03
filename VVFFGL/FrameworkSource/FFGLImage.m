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

#import <OpenGL/CGLMacro.h>

#pragma mark Private Callbacks

static void FFGLImageBufferRelease(const void *baseAddress, void* context) {
    // for now, just free the buffer, could make them reusable
    free((void *)baseAddress);
}

static void FFGLImageTextureRelease(GLuint name, CGLContextObj cgl_ctx, void *context) {
    CGLLockContext(cgl_ctx);
//	NSLog(@"delete texture %u in FFGLImage callback (converted)", name);
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
static void swapTextureTargets(CGLContextObj cgl_ctx, const FFGLTextureInfo *fromTexture, FFGLTextureInfo *toTexture, GLenum fromTarget, BOOL isFlipped)
{		
    CGLLockContext(cgl_ctx);
    
    // cache FBO state
    GLint previousFBO, previousReadFBO, previousDrawFBO;
    
    // the FBO attachment texture we are going to render to.
    GLenum toTarget;
		
    GLsizei width, height;
    // set up our destination target
    if(fromTarget == GL_TEXTURE_RECTANGLE_ARB)
	{
        toTarget = GL_TEXTURE_2D;
        width = toTexture->hardwareWidth = FFGLPOTDimension(fromTexture->width);
        height = toTexture->hardwareHeight = FFGLPOTDimension(fromTexture->height);
    } 
    else
    {
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
	
	// save as much state;
	glPushAttrib(GL_ALL_ATTRIB_BITS);
    
	// new texture
	GLuint newTex;
	glGenTextures(1, &newTex);
	
	glEnable(toTarget);
	
	glBindTexture(toTarget, newTex);
	glTexImage2D(toTarget, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);

	// texture filtering and wrapping modes for FBO texture.
	glTexParameteri(toTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(toTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(toTarget, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
	glTexParameteri(toTarget, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
	
//	NSLog(@"new texture: %u, original texture: %u", newTex, fromTexture->texture);
	toTexture->texture = newTex;

	// make new FBO and attach.
	GLuint fboID;
	glGenFramebuffersEXT(1, &fboID);
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, fboID);
	glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, toTarget, newTex, 0);

	// unbind texture
	glBindTexture(toTarget, 0);
	glDisable(toTarget);

	GLenum status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
	if(status != GL_FRAMEBUFFER_COMPLETE_EXT)
	{
	    // Anton, I added this and the following else so we cleanly abort. Look right?
				// return FBO state
		glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, previousFBO);
		glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, previousReadFBO);
		glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, previousDrawFBO);
		
		// cleanup GL resources
		glDeleteFramebuffersEXT(1, &fboID);
		glDeleteTextures(1, &newTex);
		
		CGLUnlockContext(cgl_ctx);
		NSLog(@"Cannot create FBO for swapTextureTarget: %u", status);
			
	    toTexture->texture = 0;
	}
	
	glViewport(0, 0, width, height);
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	
	// weirdo ortho
	glOrtho(0.0, width, 0.0, height, -1, 1);		
	
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();
	
	// draw the texture.
	//texture->draw(0,0);
	
	glClearColor(0,0,0,0);
	glClear(GL_COLOR_BUFFER_BIT);
	
	glActiveTexture(GL_TEXTURE0);
	glEnable(fromTarget);
	glBindTexture(fromTarget, fromTexture->texture);
	
	if(fromTarget == GL_TEXTURE_RECTANGLE_ARB)
	{	
		glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
		glTexParameteri(GL_TEXTURE_RECTANGLE_ARB, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
		
		if(isFlipped)
		{
			glBegin(GL_QUADS);
			glTexCoord2f(0, 0);
			glVertex2f(0, height);
			glTexCoord2f(0, height);
			glVertex2f(0, 0);
			glTexCoord2f(width, height);
			glVertex2f(width, 0);
			glTexCoord2f(width, 0);
			glVertex2f(width, height);
			glEnd();		
		}
		else
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
	}
	else if(fromTarget == GL_TEXTURE_2D)
	{
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
		
		// since our image is NPOT but our texture is POT, we must 
		// deduce proper texture coords in normalized space
		GLfloat texWidth = (GLfloat) fromTexture->width / (GLfloat)fromTexture->hardwareWidth;
		GLfloat texHeight = (GLfloat)fromTexture->height / (GLfloat)fromTexture->hardwareHeight;
		
		if(isFlipped)
		{
			glBegin(GL_QUADS);
			glTexCoord2f(0, 0);
			glVertex2f(0, texHeight);
			glTexCoord2f(0, 0); 
			glVertex2f(0, height);
			glTexCoord2f(texWidth, texHeight);
			glVertex2f(width, 0);
			glTexCoord2f(texWidth, 0);
			glVertex2f(width, texHeight);
			glEnd();		
			
		}
		else
		{
			glBegin(GL_QUADS);
			glTexCoord2f(0, 0);
			glVertex2f(0, 0);
			glTexCoord2f(0, texHeight); 
			glVertex2f(0, height);
			glTexCoord2f(texWidth, texHeight);
			glVertex2f(width, height);
			glTexCoord2f(texWidth, 0);
			glVertex2f(width, 0);
			glEnd();		
		}	
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
        info->hardwareWidth = width;
        info->hardwareHeight = height;
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

- (id)initWithCopiedTextureRect:(GLuint)texture CGLContext:(CGLContextObj)context pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height
{
    FFGLTextureInfo source;
    source.texture = texture;
    source.hardwareWidth = width;
    source.hardwareHeight = height;
    source.width = width;
    source.height = height;
    
    FFGLTextureInfo *dest = malloc(sizeof(FFGLTextureInfo));
    swapTextureTargets(context, &source, dest, GL_TEXTURE_RECTANGLE_ARB, NO);
    if (dest->texture == 0) {
	free(dest);
	dest = NULL; // We couldn't make the new texture. This causes the following init to fail (returns nil)
    }
    return [self initWithCGLContext:context imagePixelsWide:width imagePixelsHigh:height
		      texture2DInfo:dest texture2DReleaseCallback:FFGLImageTextureRelease texture2DReleaseInfo:NULL
		    textureRectInfo:NULL textureRectReleaseCallback:NULL textureRectReleaseInfo:NULL
			     buffer:NULL pixelFormat:nil bufferReleaseCallback:NULL bufferReleaseInfo:NULL];
    
}

- (void)releaseResources 
{
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
            swapTextureTargets(_context, (FFGLTextureInfo *)_textureRectInfo, (FFGLTextureInfo *)_texture2DInfo, GL_TEXTURE_RECTANGLE_ARB, NO);
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
	
    if (_hasTextureRect == YES) 
    {
        result = YES;
    } 
    else if (_hasTexture2D)
    {
        _textureRectInfo = malloc(sizeof(FFGLTextureInfo));
        swapTextureTargets(_context, (FFGLTextureInfo *)_texture2DInfo, (FFGLTextureInfo *)_textureRectInfo, GL_TEXTURE_2D, NO);
		
        if (((FFGLTextureInfo *)_textureRectInfo)->texture == 0)
	{
            free(_textureRectInfo);
        }
	else
	{
            _textureRectReleaseCallback = FFGLImageTextureRelease;
            _textureRectReleaseContext = NULL;
            _hasTextureRect = YES;
            result = YES;
        }
    } 
    else if (_hasBuffer) 
    {
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
@end
