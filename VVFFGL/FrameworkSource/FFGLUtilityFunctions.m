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
