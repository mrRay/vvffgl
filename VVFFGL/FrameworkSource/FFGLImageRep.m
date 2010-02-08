//
//  FFGLImageRep.m
//  VVFFGL
//
//  Created by Tom on 01/02/2010.
//  Copyright 2010 Tom Butterworth. All rights reserved.
//

#import "FFGLImageRep.h"
#import <OpenGL/CGLMacro.h>

#pragma mark Private Callbacks

static void FFGLImageRepBufferRelease(const void *baseAddress, void* context) {
    free((void *)baseAddress);
}

static void FFGLImageRepTextureRelease(GLuint name, CGLContextObj cgl_ctx, void *context) {
    CGLLockContext(cgl_ctx);
    glDeleteTextures(1, &name);
    CGLUnlockContext(cgl_ctx);
}

#pragma mark Private Utility
static BOOL ffglGLInfoForPixelFormat(NSString *ffglFormat, GLenum *format, GLenum *type)
{
	if ([ffglFormat isEqualToString:FFGLPixelFormatRGB565])
	{
		*format = GL_RGB;
		*type = GL_UNSIGNED_SHORT_5_6_5;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatRGB888])
	{
		*format = GL_RGB;
		*type = GL_UNSIGNED_BYTE;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatARGB8888])
	{ 
		*format = GL_BGRA;
		*type = GL_UNSIGNED_INT_8_8_8_8;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatBGR565])
	{
		*format = GL_RGB;
		*type = GL_UNSIGNED_SHORT_5_6_5_REV;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatBGR888])
	{
		*format = GL_BGR;
		*type = GL_UNSIGNED_BYTE;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatBGRA8888])
	{ 
		*format = GL_BGRA;
		*type = GL_UNSIGNED_INT_8_8_8_8_REV;
	}
	else {
		return NO;
	}
	return YES;
}

#pragma mark FFGLImageRep

FFGLImageRep *FFGLBufferRepCreateFromTextureRep(CGLContextObj cgl_ctx, const FFGLImageRep *fromTextureRep, NSString *pixelFormat)
{
	GLenum targetGL;
	if (fromTextureRep->type == FFGLImageRepTypeTexture2D)
	{
		// If our source has POT dimensions beyond its bounds, we fail. In that case,
		// the caller should first create a rect texture then convert from that
		if (fromTextureRep->repInfo.textureInfo.hardwareWidth != fromTextureRep->repInfo.textureInfo.width
			|| fromTextureRep->repInfo.textureInfo.hardwareHeight != fromTextureRep->repInfo.textureInfo.height
			)
		{
			return NULL;
		}
		else
		{
			targetGL = GL_TEXTURE_2D;
		}
	}
	else if (fromTextureRep->type == FFGLImageRepTypeTextureRect)
	{
		targetGL = GL_TEXTURE_RECTANGLE_ARB;
	}
	else
	{
		return NULL;
	}
	
	GLenum format, type;
	if (ffglGLInfoForPixelFormat(pixelFormat, &format, &type) == NO)
	{
		return NULL;
	}
	unsigned int rowBytes = fromTextureRep->repInfo.textureInfo.hardwareWidth * ffglBytesPerPixelForPixelFormat(pixelFormat);
	GLvoid *buffer = valloc(rowBytes * fromTextureRep->repInfo.textureInfo.hardwareHeight);
	if (buffer == NULL)
	{
		return NULL;
	}
	
	CGLLockContext(cgl_ctx);
	
	// Save state
	glPushAttrib(GL_TEXTURE_BIT | GL_ENABLE_BIT);
	glPushClientAttrib(GL_CLIENT_PIXEL_STORE_BIT);
	
	// Make sure pixel-storage is set up as we need it
	glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
	glPixelStorei(GL_PACK_ROW_LENGTH, 0);
	glPixelStorei(GL_PACK_IMAGE_HEIGHT, 0);
	glPixelStorei(GL_PACK_ALIGNMENT, 1);
	glPixelStorei(GL_PACK_LSB_FIRST, GL_FALSE);
	glPixelStorei(GL_PACK_SKIP_IMAGES, 0);
	glPixelStorei(GL_PACK_SKIP_PIXELS, 0);
	glPixelStorei(GL_PACK_SKIP_ROWS, 0);
	glPixelStorei(GL_PACK_SWAP_BYTES, GL_FALSE);
	
	// Get the pixel data
	glEnable(targetGL);
	glBindTexture(targetGL, fromTextureRep->repInfo.textureInfo.texture);
	glGetTexImage(targetGL, 0, format, type, buffer);
	
	// Check for error
	GLenum error = glGetError();
	
	// Restore state
	glPopClientAttrib();
	glPopAttrib();
	
	CGLUnlockContext(cgl_ctx);
	
	if (error != GL_NO_ERROR)
	{
		free(buffer);
		return NULL;
	}
	
	FFGLImageRep *rep = FFGLBufferRepCreateFromBuffer(buffer,
													  fromTextureRep->repInfo.textureInfo.width,
													  fromTextureRep->repInfo.textureInfo.height,
													  rowBytes, pixelFormat, fromTextureRep->flipped,
													  FFGLImageRepBufferRelease, NULL, NO);
	return rep;
}

FFGLImageRep *FFGLTextureRepCreateFromBufferRep(CGLContextObj cgl_ctx, const FFGLImageRep *fromBufferRep, FFGLImageRepType toTarget, BOOL useNPOT)
{
	GLenum targetGL;
	
	// We fail if the image does not fill the texture (eg some POT-dimensioned 2D textures)
	// because it is quicker to do buffer->rect->2d than to create a temporary scaled buffer
	
	unsigned int texWidth, texHeight;
	texWidth = fromBufferRep->repInfo.bufferInfo.width;
	texHeight = fromBufferRep->repInfo.bufferInfo.height;
	
	if (toTarget == FFGLImageRepTypeTexture2D)
	{
		targetGL = GL_TEXTURE_2D;
		if (!useNPOT
			&& (texWidth != ffglPOTDimension(texWidth) || texHeight != ffglPOTDimension(texHeight))
			)
		{
			return NULL;
		}
	}
	else if (toTarget == FFGLImageRepTypeTextureRect)
	{
		targetGL = GL_TEXTURE_RECTANGLE_ARB;
	}
	else
	{
		return NULL;
	}
	
	GLenum format;
	GLenum type;
	if (ffglGLInfoForPixelFormat(fromBufferRep->repInfo.bufferInfo.pixelFormat, &format, &type) == NO)
	{
		return NULL;
	}
	
	CGLLockContext(cgl_ctx);
	
	// Save state
	glPushAttrib(GL_TEXTURE_BIT | GL_ENABLE_BIT);
	glPushClientAttrib(GL_CLIENT_PIXEL_STORE_BIT);
	
	glEnable(targetGL);
	
	// Make our new texture
	GLuint tex;
	glGenTextures(1, &tex);
	glBindTexture(targetGL, tex);
	
	// Set up the environment for unpacking
	glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glPixelStorei(GL_UNPACK_ROW_LENGTH, fromBufferRep->repInfo.bufferInfo.width);
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
	glTextureRangeAPPLE(targetGL, fromBufferRep->repInfo.bufferInfo.width * fromBufferRep->repInfo.bufferInfo.height, fromBufferRep->repInfo.bufferInfo.buffer);
#endif
	
	glTexParameteri(targetGL, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(targetGL, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(targetGL, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(targetGL, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(targetGL, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
	
	glTexImage2D(targetGL, 0, GL_RGBA8, texWidth, texHeight, 0, format, type, fromBufferRep->repInfo.bufferInfo.buffer);
	
	GLenum error = glGetError();
	// We get the error now but wait until we've popped attributes so our texture is unbound
	// when we delete it.
	
	// restore state.
	glPopClientAttrib();
	glPopAttrib();
	
	FFGLImageRep *rep;
	
	if (error != GL_NO_ERROR)
	{
		glDeleteTextures(1, &tex);
		rep = NULL;
	}
	else
	{
		rep = FFGLTextureRepCreateFromTexture(tex,
											  toTarget,
											  fromBufferRep->repInfo.bufferInfo.width,
											  fromBufferRep->repInfo.bufferInfo.height,
											  texWidth,
											  texHeight,
											  NO,
											  FFGLImageRepTextureRelease,
											  NULL);
	}
	CGLUnlockContext(cgl_ctx);
	return rep;
}

FFGLImageRep *FFGLTextureRepCreateFromTextureRep(CGLContextObj cgl_ctx, const FFGLImageRep *fromTextureRep, FFGLImageRepType toTarget, BOOL useNPOT)
{
    if (cgl_ctx == NULL
		|| fromTextureRep == NULL
		|| (fromTextureRep->type != FFGLImageRepTypeTexture2D && fromTextureRep->type != FFGLImageRepTypeTextureRect)
		|| fromTextureRep->repInfo.textureInfo.width == 0
		|| fromTextureRep->repInfo.textureInfo.height == 0
		)
    {
		return NULL;
    }
	// direct access to the FFGLTextureInfo and texture target of the source
	const FFGLTextureInfo *fromTexture = &fromTextureRep->repInfo.textureInfo;
	GLenum fromGLTarget = fromTextureRep->type == FFGLImageRepTypeTexture2D ? GL_TEXTURE_2D : GL_TEXTURE_RECTANGLE_ARB;
	GLenum toGLTarget = toTarget == FFGLImageRepTypeTexture2D ? GL_TEXTURE_2D : GL_TEXTURE_RECTANGLE_ARB;
	
	// cache FBO state
	GLint previousFBO, previousReadFBO, previousDrawFBO;
	
	// the FBO attachment texture we are going to render to.
	
	GLsizei fboWidth, fboHeight;
	// set up our destination target
	if((toGLTarget == GL_TEXTURE_2D) && (!useNPOT))
	{
		fboWidth = ffglPOTDimension(fromTexture->width);
		fboHeight = ffglPOTDimension(fromTexture->height);
	} 
	else
	{
		fboWidth = fromTexture->width;
		fboHeight = fromTexture->height;
	}
	
	CGLLockContext(cgl_ctx);
	
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
		NSLog(@"Cannot create FBO for swapTextureTarget: %u", status);
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
		glEnable(fromGLTarget);
		glBindTexture(fromGLTarget, fromTexture->texture);
		
		glTexParameteri(fromGLTarget, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(fromGLTarget, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(fromGLTarget, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(fromGLTarget, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);				
		glTexParameteri(fromGLTarget, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);				
		
		//				GLfloat texImageWidth, texImageHeight;
		//
		//				texImageWidth = fromGLTarget == GL_TEXTURE_2D ? (GLfloat) fromTexture->width / (GLfloat)fromTexture->hardwareWidth : fromTexture->width;
		//				texImageHeight = fromGLTarget == GL_TEXTURE_2D ? (GLfloat)fromTexture->height / (GLfloat)fromTexture->hardwareHeight : fromTexture->height;
		//				GLfloat fboImageWidth, fboImageHeight;
		//				fboImageWidth = toTexture->width;
		//				fboImageHeight = toTexture->height;
		//				NSLog(@"%@ -> %@ flipped: %@ texWidth: %f texHeight: %f fboImageWidth: %d fboImageHeight: %d", fromTarget == GL_TEXTURE_2D ? @"2D" : @"Rect", toTarget == GL_TEXTURE_2D ? @"2D" : @"Rect", fromTextureRep->flipped ? @"YES" : @"NO", texWidth, texHeight, fboImageWidth, fboImageHeight);
		
		GLfloat tax, tay, tbx, tby, tcx, tcy, tdx, tdy, vax, vay, vbx, vby, vcx, vcy, vdx, vdy;
		
		tax = tay = tbx = tdy = 0.0;
		tby = tcy = (fromGLTarget == GL_TEXTURE_2D ? (GLfloat)fromTexture->height / (GLfloat)fromTexture->hardwareHeight : fromTexture->height);
		tcx = tdx = (fromGLTarget == GL_TEXTURE_2D ? (GLfloat) fromTexture->width / (GLfloat)fromTexture->hardwareWidth : fromTexture->width);
		
		GLfloat tex_coords[] =
		{
			tax, tay,
			tbx, tby,
			tcx, tcy,
			tdx, tdy
		};
		
		vax = vbx = 0.0;
		vcx = vdx = fromTexture->width;
		
		if (fromTextureRep->flipped)
		{
			vay = vdy = fromTexture->height;
			vby = vcy = 0.0;
		}
		else
		{
			vay = vdy = 0.0;
			vby = vcy = fromTexture->height;
		}
		
		GLfloat verts[] =
		{
			vax, vay,
			vbx, vby,
			vcx, vcy,
			vdx, vdy
		};
		
		glDisableClientState(GL_COLOR_ARRAY);
		glDisableClientState(GL_EDGE_FLAG_ARRAY);
		glDisableClientState(GL_INDEX_ARRAY);
		glDisableClientState(GL_NORMAL_ARRAY);
		glEnableClientState( GL_TEXTURE_COORD_ARRAY );
		glTexCoordPointer(2, GL_FLOAT, 0, tex_coords );
		glEnableClientState(GL_VERTEX_ARRAY);
		glVertexPointer(2, GL_FLOAT, 0, verts );
		glDrawArrays(GL_QUADS, 0, 4);
	}
	glBindTexture(fromGLTarget, 0);
	
	// Restore OpenGL states 
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
	
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
	
	CGLUnlockContext(cgl_ctx);
    
	FFGLImageRep *rep = FFGLTextureRepCreateFromTexture(newTex, toTarget, fromTexture->width, fromTexture->height, fboWidth, fboHeight, NO, FFGLImageRepTextureRelease, NULL);
    return rep;
}

FFGLImageRep *FFGLTextureRepCreateFromTexture(GLint texture, FFGLImageRepType type, NSUInteger imageWidth, NSUInteger imageHeight, NSUInteger textureWidth, NSUInteger textureHeight, BOOL isFlipped, FFGLImageTextureReleaseCallback callback, void *userInfo)
{
	FFGLImageRep *rep = malloc(sizeof(FFGLImageRep));
	if (rep != NULL)
	{
	    rep->type = type;
	    rep->releaseCallback.textureCallback = callback;
	    rep->releaseContext = userInfo;
	    rep->repInfo.textureInfo.texture = texture;
	    rep->repInfo.textureInfo.width = imageWidth;
	    rep->repInfo.textureInfo.height = imageHeight;
	    rep->repInfo.textureInfo.hardwareWidth = textureWidth;
	    rep->repInfo.textureInfo.hardwareHeight = textureHeight;
	    rep->flipped = isFlipped;
	}
	return rep;
}
FFGLImageRep *FFGLBufferRepCreateFromBuffer(const void *source, NSUInteger width, NSUInteger height, NSUInteger rowBytes, NSString *pixelFormat, BOOL isFlipped, FFGLImageBufferReleaseCallback callback, void *userInfo, BOOL forceCopy)
{
	FFGLImageRep *rep;
    NSUInteger bpp = ffglBytesPerPixelForPixelFormat(pixelFormat);
	if (source == NULL
		|| width == 0
		|| height == 0
		|| rowBytes == 0
		|| bpp == 0)
		return NULL;
	
	rep = malloc(sizeof(FFGLImageRep));
	if (rep != NULL)
	{
		if ((width * bpp) != rowBytes || isFlipped || forceCopy) {
			// FF plugins don't support pixel buffers where image width != row width.
			// We could just fiddle the reported image width, but this would give wrong results if the plugin takes borders into account.
			// We also flip buffers the right way up because we don't support upside down buffers - though FF plugins do...
			// In these cases we make a new buffer with no padding.
			unsigned int i;
			int newRowBytes = width * bpp;
			void *newBuffer = valloc(width * bpp * height);
			if (newBuffer == NULL)
			{
				free(rep);
				return NULL;
			}
			const void *s = source;
			void *d = newBuffer + (isFlipped ? newRowBytes * (height - 1) : 0);
			int droller = isFlipped ? -newRowBytes : newRowBytes;
			for (i = 0; i < height; i++) {
				memcpy(d, s, newRowBytes);
				s+=rowBytes;
				d+=droller;
			}
			if (callback)
				callback(source, userInfo);
			source = newBuffer;
			callback = FFGLImageRepBufferRelease;
			userInfo = NULL;
		}
		rep->flipped = NO;
		rep->releaseCallback.bufferCallback = callback;
		rep->releaseContext = userInfo;
		rep->type = FFGLImageRepTypeBuffer;
		rep->repInfo.bufferInfo.buffer = source;
		rep->repInfo.bufferInfo.width = width;
		rep->repInfo.bufferInfo.height = height;
		rep->repInfo.bufferInfo.pixelFormat = [pixelFormat retain];
	}
	return rep;
}

void FFGLImageRepDestroy(CGLContextObj cgl_ctx, FFGLImageRep *rep)
{
	if (rep->type == FFGLImageRepTypeTexture2D || rep->type == FFGLImageRepTypeTextureRect)
	{
		if (rep->releaseCallback.textureCallback != NULL)
		{
			CGLContextObj prevContext;
			ffglSetContext(cgl_ctx, prevContext);
			rep->releaseCallback.textureCallback(rep->repInfo.textureInfo.texture, cgl_ctx, rep->releaseContext);
			ffglRestoreContext(cgl_ctx, prevContext);
		}
			
    }
    else if (rep->type == FFGLImageRepTypeBuffer)
    {
		[rep->repInfo.bufferInfo.pixelFormat release];
		if (rep->releaseCallback.bufferCallback != NULL)
			rep->releaseCallback.bufferCallback(rep->repInfo.bufferInfo.buffer, rep->releaseContext);
    }
	free(rep);
}