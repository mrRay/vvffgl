/*
 *  FFGLUtilityFunctions.c
 *  VVFFGL
 *
 *  Created by Tom on 07/01/2010.
 *  Copyright 2010 Tom Butterworth. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/CGLMacro.h>
#import "FFGLPlugin.h"
#import <strings.h>
#import <stdbool.h>

bool ffglOpenGLSupportsExtension(CGLContextObj cgl_ctx, const char *extension)

{
	// Adapted from http://www.opengl.org/resources/features/OGLextensions/
	// Weirdly faster than gluCheckExtension()

	const GLubyte *extensions = NULL;
	const GLubyte *start;
	GLubyte *where, *terminator;
	
	// Check for illegal spaces in extension name
	where = (GLubyte *) strchr(extension, ' ');
	if (where || *extension == '\0')
		return false;
	
	extensions = glGetString(GL_EXTENSIONS);

	start = extensions;
	for (;;) {
		
		where = (GLubyte *) strstr((const char *) start, extension);
		
		if (!where)
			break;
		
		terminator = where + strlen(extension);
		
		if (where == start || *(where - 1) == ' ')
			if (*terminator == ' ' || *terminator == '\0')
				return true;
		
		start = terminator;
	}
	return false;
}

bool ffglGLInfoForPixelFormat(NSString *ffglFormat, GLenum *format, GLenum *type, unsigned int *bytesPerPixel)
{
	// Check platform-endian pixel-formats first to minimise string comparisons
#if __BIG_ENDIAN__
	if ([ffglFormat isEqualToString:FFGLPixelFormatARGB8888])
	{ 
		*format = GL_BGRA;
		*type = GL_UNSIGNED_INT_8_8_8_8;
		*bytesPerPixel = 4;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatRGB888])
	{
		*format = GL_RGB;
		*type = GL_UNSIGNED_BYTE;
		*bytesPerPixel = 3;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatRGB565])
	{
		*format = GL_RGB;
		*type = GL_UNSIGNED_SHORT_5_6_5;
		*bytesPerPixel = 2;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatBGRA8888])
	{ 
		*format = GL_BGRA;
		*type = GL_UNSIGNED_INT_8_8_8_8_REV;
		*bytesPerPixel = 4;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatBGR888])
	{
		*format = GL_BGR;
		*type = GL_UNSIGNED_BYTE;
		*bytesPerPixel = 3;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatBGR565])
	{
		*format = GL_RGB;
		*type = GL_UNSIGNED_SHORT_5_6_5_REV;
		*bytesPerPixel = 2;
	}	
#else
	if ([ffglFormat isEqualToString:FFGLPixelFormatBGRA8888])
	{ 
		*format = GL_BGRA;
		*type = GL_UNSIGNED_INT_8_8_8_8_REV;
		*bytesPerPixel = 4;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatBGR888])
	{
		*format = GL_BGR;
		*type = GL_UNSIGNED_BYTE;
		*bytesPerPixel = 3;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatBGR565])
	{
		*format = GL_RGB;
		*type = GL_UNSIGNED_SHORT_5_6_5_REV;
		*bytesPerPixel = 2;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatARGB8888])
	{ 
		*format = GL_BGRA;
		*type = GL_UNSIGNED_INT_8_8_8_8;
		*bytesPerPixel = 4;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatRGB888])
	{
		*format = GL_RGB;
		*type = GL_UNSIGNED_BYTE;
		*bytesPerPixel = 3;
	}
	else if ([ffglFormat isEqualToString:FFGLPixelFormatRGB565])
	{
		*format = GL_RGB;
		*type = GL_UNSIGNED_SHORT_5_6_5;
		*bytesPerPixel = 2;
	}
#endif
	else {
		return false;
	}
	return true;
}

NSUInteger ffglBytesPerPixelForPixelFormat(NSString *pixelFormat)
{
	GLenum format, type;
	unsigned int bpp;
	if (ffglGLInfoForPixelFormat(pixelFormat, &format, &type, &bpp) == true)
	{
		return bpp;
	}
	else
	{
		return 0;
	}
}

void ffglDrawTexture(CGLContextObj cgl_ctx, GLuint texture, GLenum target, Boolean isFlipped,
					 unsigned int srcPixelWidth, unsigned int srcPixelHeight, unsigned int srcTextureWidth, unsigned int srcTextureHeight,
					 NSRect srcFromRect, NSRect dstToRect)
{
	
	glEnable(target);
	glBindTexture(target, texture);
	
	glTexParameteri(target, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(target, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(target, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(target, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);				
	glTexParameteri(target, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
	
	glColor4f(1.0, 1.0, 1.0, 1.0);

	GLfloat tax, tay, tbx, tby, tcx, tcy, tdx, tdy, vax, vay, vbx, vby, vcx, vcy, vdx, vdy;
	
	tax = tbx = (target == GL_TEXTURE_2D ? (GLfloat)srcFromRect.origin.x / (GLfloat)srcTextureWidth : srcFromRect.origin.x);
	tay = tdy = (target == GL_TEXTURE_2D ? (GLfloat)srcFromRect.origin.y / (GLfloat)srcTextureHeight : srcFromRect.origin.y);
	tby = tcy = (target == GL_TEXTURE_2D ? (GLfloat)(srcFromRect.origin.y + srcFromRect.size.height) / (GLfloat)srcTextureHeight : (GLfloat)(srcFromRect.origin.y + srcFromRect.size.height));
	tcx = tdx = (target == GL_TEXTURE_2D ? (GLfloat)(srcFromRect.origin.x + srcFromRect.size.width) / (GLfloat)srcTextureWidth : (srcFromRect.origin.x + srcFromRect.size.width));
	
	GLfloat tex_coords[] =
	{
		tax, tay,
		tbx, tby,
		tcx, tcy,
		tdx, tdy
	};
	
	vax = vbx = dstToRect.origin.x;
	vcx = vdx = dstToRect.origin.x + dstToRect.size.width;
	
	if (isFlipped)
	{
		vay = vdy = dstToRect.origin.y + dstToRect.size.height;
		vby = vcy = dstToRect.origin.y;
	}
	else
	{
		vay = vdy = dstToRect.origin.y;
		vby = vcy = dstToRect.origin.y + dstToRect.size.height;
	}
	
	GLfloat verts[] =
	{
		vax, vay,
		vbx, vby,
		vcx, vcy,
		vdx, vdy
	};
	
	/*
	 // The following seems to upset things weirdly. Not sure why...
	 glDisableClientState(GL_COLOR_ARRAY);
	 glDisableClientState(GL_EDGE_FLAG_ARRAY);
	 glDisableClientState(GL_INDEX_ARRAY);
	 glDisableClientState(GL_NORMAL_ARRAY);
	 */
	glEnableClientState( GL_TEXTURE_COORD_ARRAY );
	glTexCoordPointer(2, GL_FLOAT, 0, tex_coords );
	glEnableClientState(GL_VERTEX_ARRAY);
	glVertexPointer(2, GL_FLOAT, 0, verts );
	glDrawArrays(GL_QUADS, 0, 4);
	
	glBindTexture(target, 0);
}
