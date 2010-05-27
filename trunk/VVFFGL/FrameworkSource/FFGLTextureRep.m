//
//  FFGLTextureRep.m
//  VVFFGL
//
//  Created by Tom on 11/02/2010.
//

#import "FFGLTextureRep.h"
#import "FFGLBufferRep.h"
#import <OpenGL/CGLMacro.h>

static void FFGLTextureRepTextureDelete(GLuint name, CGLContextObj cgl_ctx, void *context)
{
    glDeleteTextures(1, &name);
}

typedef struct FFGLTextureRepPackedBufferCallback
{
	const void *baseAddress;
	FFGLImageBufferReleaseCallback callback;
	void *userInfo;
} FFGLTextureRepPackedBufferCallback;

static void FFGLTextureRepBufferPerformCallback(GLuint name, CGLContextObj cgl_ctx, void *packedCallback)
{
	if (((FFGLTextureRepPackedBufferCallback *)packedCallback)->callback != NULL)
	{
		((FFGLTextureRepPackedBufferCallback *)packedCallback)->callback(((FFGLTextureRepPackedBufferCallback *)packedCallback)->baseAddress,
																		 ((FFGLTextureRepPackedBufferCallback *)packedCallback)->userInfo);
	}
	free(packedCallback);
	glDeleteTextures(1, &name);
}

@implementation FFGLTextureRep

- (id)copyAsType:(FFGLImageRepType)type pixelFormat:(NSString *)pixelFormat inContext:(CGLContextObj)context allowingNPOT2D:(BOOL)useNPOT asPrimaryRep:(BOOL)isPrimary
{
	FFGLTextureRep *temp;
	switch (type) {
		case FFGLImageRepTypeTexture2D:
		case FFGLImageRepTypeTextureRect:
			// Texture copies always produce a non-flipped texture and shouldn't fail
			// so we can simply...
			return [[FFGLTextureRep alloc] initCopyingTexture:_textureInfo.texture
													   ofType:_type
													  context:context
												   imageWidth:_textureInfo.width
												  imageHeight:_textureInfo.height
												 textureWidth:_textureInfo.hardwareWidth
												textureHeight:_textureInfo.hardwareHeight
													isFlipped:_isFlipped
													   toType:type
												 allowingNPOT:useNPOT
												 asPrimaryRep:isPrimary];
			break;
		case FFGLImageRepTypeBuffer:
			// We ALWAYS do a texture copy first. This is to work around a weird issue with
			// some textures from CoreVideo which won't glGetTexImage their content.
			// If we find a solution to that problem, then we only need to do a texture copy
			// if a) we have texture dimensions beyond our image dimensions (POT 2D),
			// OR b) are flipped.
			temp = [[FFGLTextureRep alloc] initCopyingTexture:_textureInfo.texture
													   ofType:_type
													  context:context
												   imageWidth:_textureInfo.width
												  imageHeight:_textureInfo.height
												 textureWidth:_textureInfo.hardwareWidth
												textureHeight:_textureInfo.hardwareHeight
													isFlipped:_isFlipped
													   toType:FFGLImageRepTypeTextureRect
												 allowingNPOT:useNPOT
												 asPrimaryRep:isPrimary];
			FFGLTextureInfo *texInfo = temp.textureInfo;
			FFGLBufferRep *rep = [[FFGLBufferRep alloc] initFromNonFlippedTexture:texInfo->texture
																		   ofType:FFGLImageRepTypeTextureRect
																		  context:context
																	   imageWidth:texInfo->width
																	  imageHeight:texInfo->height
																	 textureWidth:texInfo->hardwareWidth
																	textureHeight:texInfo->hardwareHeight
																	toPixelFormat:pixelFormat
																	 allowingNPOT:useNPOT
																	 asPrimaryRep:isPrimary];
			[temp release];
			return rep;
			break;
		default:
			return nil;
			break;
	}
}

- (id)initWithTexture:(GLint)texture context:(CGLContextObj)context ofType:(FFGLImageRepType)type imageWidth:(NSUInteger)imageWidth imageHeight:(NSUInteger)imageHeight textureWidth:(NSUInteger)textureWidth textureHeight:(NSUInteger)textureHeight isFlipped:(BOOL)flipped callback:(FFGLImageTextureReleaseCallback)callback userInfo:(void *)userInfo asPrimaryRep:(BOOL)isPrimary
{
	if (self = [super initAsType:type isFlipped:flipped asPrimaryRep:isPrimary])
	{
		_textureInfo.width = imageWidth;
		_textureInfo.height = imageHeight;
		_textureInfo.hardwareWidth = textureWidth;
		_textureInfo.hardwareHeight = textureHeight;
		_textureInfo.texture = texture;
		_callback = callback;
		_userInfo = userInfo;
		_context = context;
	}
	return self;
}

- (id)initCopyingTexture:(GLint)texture ofType:(FFGLImageRepType)fromType context:(CGLContextObj)cgl_ctx imageWidth:(NSUInteger)imageWidth imageHeight:(NSUInteger)imageHeight textureWidth:(NSUInteger)fromTextureWidth textureHeight:(NSUInteger)fromTextureHeight isFlipped:(BOOL)flipped toType:(FFGLImageRepType)toType allowingNPOT:(BOOL)useNPOT asPrimaryRep:(BOOL)isPrimary
{
	if (cgl_ctx == NULL
		|| (fromType != FFGLImageRepTypeTexture2D && fromType != FFGLImageRepTypeTextureRect)
		|| fromTextureWidth == 0
		|| fromTextureHeight == 0
		)
    {
		[self release];
		return nil;
    }

	GLenum fromGLTarget = fromType == FFGLImageRepTypeTexture2D ? GL_TEXTURE_2D : GL_TEXTURE_RECTANGLE_ARB;
	GLenum toGLTarget = toType == FFGLImageRepTypeTexture2D ? GL_TEXTURE_2D : GL_TEXTURE_RECTANGLE_ARB;
	
	// cache FBO state
	GLint previousFBO, previousReadFBO, previousDrawFBO;
	
	// the FBO attachment texture we are going to render to.
	
	GLsizei fboWidth, fboHeight;
	// set up our destination target
	if((toGLTarget == GL_TEXTURE_2D) && (!useNPOT))
	{
		fboWidth = ffglPOTDimension(fromTextureWidth);
		fboHeight = ffglPOTDimension(fromTextureHeight);
	} 
	else
	{
		fboWidth = fromTextureWidth;
		fboHeight = fromTextureHeight;
	}
	
	glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &previousFBO);
	glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &previousReadFBO);
	glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &previousDrawFBO);
	
	// save as much state;
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	glPushClientAttrib(GL_CLIENT_VERTEX_ARRAY_BIT);
	// new texture
	GLuint newTex;
	glGenTextures(1, &newTex);
	
	glEnable(toGLTarget);
	
	glBindTexture(toGLTarget, newTex);
	glTexImage2D(toGLTarget, 0, GL_RGBA8, fboWidth, fboHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	
	// texture filtering and wrapping modes for FBO texture.
	glTexParameteri(toGLTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(toGLTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(toGLTarget, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(toGLTarget, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(toGLTarget, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
	
	//	NSLog(@"new texture: %u, original texture: %u", newTex, fromTexture->texture);
	
	// make new FBO and attach.
	GLuint fboID;
	glGenFramebuffersEXT(1, &fboID);
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, fboID);
	glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, toGLTarget, newTex, 0);
	
	// unbind texture
	glBindTexture(toGLTarget, 0);
	glDisable(toGLTarget);
	
	GLenum status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
	if(status != GL_FRAMEBUFFER_COMPLETE_EXT)
	{
		glDeleteTextures(1, &newTex);
	}
	else // FBO creation worked, carry on
	{	
		glViewport(0, 0, fboWidth, fboHeight);
		glMatrixMode(GL_PROJECTION);
		glPushMatrix();
		glLoadIdentity();
		
		// weirdo ortho
		glOrtho(0.0, fboWidth, 0.0, fboHeight, -1, 1);		
		
		glMatrixMode(GL_MODELVIEW);
		glPushMatrix();
		glLoadIdentity();
		
		// draw the texture.
		
		glActiveTexture(GL_TEXTURE0);
		ffglDrawTexture(cgl_ctx, texture, fromGLTarget, flipped,
						imageWidth, imageHeight, fromTextureWidth, fromTextureHeight,
						(NSRect){0.0, 0.0, imageWidth, imageHeight}, (NSRect){0.0, 0.0, imageWidth, imageHeight});

		// Restore OpenGL states 
		glMatrixMode(GL_MODELVIEW);
		glPopMatrix();
		glMatrixMode(GL_PROJECTION);
		glPopMatrix();
	}
	
	// restore states // assume this is balanced with above
	glPopClientAttrib();
	glPopAttrib();
	
	// pop back to old FBO
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, previousFBO);	
	glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, previousReadFBO);
	glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, previousDrawFBO);
	
	glFlushRenderAPPLE();
	
	// delete our FBO so we dont leak.
	glDeleteFramebuffersEXT(1, &fboID);
	
	if (status == GL_FRAMEBUFFER_COMPLETE_EXT)
	{
		return [self initWithTexture:newTex
							 context:cgl_ctx
							  ofType:toType
						  imageWidth:imageWidth imageHeight:imageHeight
						textureWidth:fboWidth textureHeight:fboHeight
						   isFlipped:NO
							callback:FFGLTextureRepTextureDelete userInfo:NULL
						asPrimaryRep:isPrimary];
	}
	else
	{
		[self release];
		return nil;
	}

}

- (id)initFromBuffer:(const void *)buffer context:(CGLContextObj)cgl_ctx width:(NSUInteger)width height:(NSUInteger)height bytesPerRow:(NSUInteger)rowBytes pixelFormat:(NSString *)pixelFormat isFlipped:(BOOL)flipped toType:(FFGLImageRepType)toType callback:(FFGLImageBufferReleaseCallback)callback userInfo:(void *)userInfo allowingNPOT:(BOOL)useNPOT asPrimaryRep:(BOOL)isPrimary
{
	GLenum targetGL;
	
	// We fail if the image does not fill the texture (eg some POT-dimensioned 2D textures)
	// because it is quicker to do buffer->rect->2d than to create a temporary scaled buffer
	
	unsigned int texWidth, texHeight, bytesPerPixel;
	texWidth = width;
	texHeight = height;
	GLenum format;
	GLenum type;
	
	if (
		( (toType != FFGLImageRepTypeTexture2D) && (toType != FFGLImageRepTypeTextureRect) )
		|| (ffglGLInfoForPixelFormat(pixelFormat, &format, &type, &bytesPerPixel) == false)
		|| ( (toType == FFGLImageRepTypeTexture2D) && !useNPOT
			&& ( (texWidth != ffglPOTDimension(texWidth)) || (texHeight != ffglPOTDimension(texHeight)) )
			)
		)
		{
			[self release];
			return nil;
		}
	if (toType == FFGLImageRepTypeTexture2D)
	{
		targetGL = GL_TEXTURE_2D;
	}
	else if (toType == FFGLImageRepTypeTextureRect)
	{
		targetGL = GL_TEXTURE_RECTANGLE_ARB;
	}
		
	// Save state
	glPushAttrib(GL_TEXTURE_BIT | GL_ENABLE_BIT);
	glPushClientAttrib(GL_CLIENT_PIXEL_STORE_BIT);
	
	glEnable(targetGL);
	
	glActiveTexture(GL_TEXTURE0);
	// Make our new texture
	GLuint tex;
	glGenTextures(1, &tex);
	glBindTexture(targetGL, tex);
	
	// Set up the environment for unpacking
	glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glPixelStorei(GL_UNPACK_ROW_LENGTH, rowBytes / bytesPerPixel);
	glPixelStorei(GL_UNPACK_IMAGE_HEIGHT, 0);
	glPixelStorei(GL_UNPACK_LSB_FIRST, GL_FALSE);
	glPixelStorei(GL_UNPACK_SKIP_IMAGES, 0);
	glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
	glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);
	glPixelStorei(GL_UNPACK_SWAP_BYTES, GL_FALSE);
	
	// GL_UNPACK_CLIENT_STORAGE_APPLE tells GL to use our buffer in memory if possible, to avoid a copy to the GPU.
	glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
	
#if defined(FFGL_USE_TEXTURE_RANGE)
	// Set storage hint GL_STORAGE_SHARED_APPLE to tell GL to share storage with main memory.
	glTexParameteri(targetGL, GL_TEXTURE_STORAGE_HINT_APPLE , GL_STORAGE_SHARED_APPLE);
	glTextureRangeAPPLE(targetGL, rowBytes * height, buffer);
#endif
	
	glTexParameteri(targetGL, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(targetGL, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(targetGL, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(targetGL, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(targetGL, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
	
	glTexImage2D(targetGL, 0, GL_RGBA8, texWidth, texHeight, 0, format, type, buffer);
	
	GLenum error = glGetError();
	// We get the error now but wait until we've popped attributes so our texture is unbound
	// when we delete it.
	
	// restore state.
	glPopClientAttrib();
	glPopAttrib();
	
	
	
	if (error != GL_NO_ERROR)
	{
		glDeleteTextures(1, &tex);
		[self release];
		return nil;
	}

	// Pack the buffer callback into a struct so we can pass it to our own callback...
	// The struct is freed in the callback, along with the texture we created
	
	FFGLTextureRepPackedBufferCallback *packed = malloc(sizeof(FFGLTextureRepPackedBufferCallback));
	if (packed == NULL)
	{
		glDeleteTextures(1, &tex);
		[self release];
		return nil;
	}
	packed->baseAddress = buffer;
	packed->callback = callback;
	packed->userInfo = userInfo;
	
	return [self initWithTexture:tex
						 context:cgl_ctx
						  ofType:toType
					  imageWidth:width
					 imageHeight:height
					textureWidth:texWidth
				   textureHeight:texHeight
					   isFlipped:flipped
						callback:FFGLTextureRepBufferPerformCallback
						userInfo:packed
					asPrimaryRep:isPrimary];
	
}
- (void)performCallbackPriorToRelease
{
	if (_callback != NULL)
	{
		_callback(_textureInfo.texture, _context, _userInfo);
		_callback = NULL;
	}	
}

- (void)finalize
{
	[self performCallbackPriorToRelease];
	[super finalize];
}

- (void)dealloc
{
	[self performCallbackPriorToRelease];
	[super dealloc];
}

- (FFGLTextureInfo *)textureInfo
{
	return &_textureInfo;
}

-(BOOL)conformsToFreeFrame
{
	if (_type == FFGLImageRepTypeTextureRect
		|| _isFlipped)
	{
		return NO;
	}
	else
	{
		return YES;
	}
}

- (void)drawInContext:(CGLContextObj)context inRect:(NSRect)destRect fromRect:(NSRect)srcRect
{
	GLenum target = _type == FFGLImageRepTypeTexture2D ? GL_TEXTURE_2D : GL_TEXTURE_RECTANGLE_ARB;
	// Save state
	CGLContextObj cgl_ctx = context;
	glPushAttrib(GL_ALL_ATTRIB_BITS);
	ffglDrawTexture(context, _textureInfo.texture, target, _isFlipped,
					_textureInfo.width, _textureInfo.height, _textureInfo.hardwareWidth, _textureInfo.hardwareHeight,
					srcRect, destRect);
	// Restore state
	glPopAttrib();
}
@end
