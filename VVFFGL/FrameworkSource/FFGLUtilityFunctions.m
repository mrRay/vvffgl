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

	const GLubyte *extensions = NULL;
	const GLubyte *start;
	GLubyte *where, *terminator;
	
	// Check for illegal spaces in extension name
	where = (GLubyte *) strchr(extension, ' ');
	if (where || *extension == '\0')
		return false;
	
	CGLLockContext(cgl_ctx);
	extensions = glGetString(GL_EXTENSIONS);
	CGLUnlockContext(cgl_ctx);
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

NSUInteger ffglBytesPerPixelForPixelFormat(NSString *format)
{
     if ([format isEqualToString:FFGLPixelFormatBGRA8888] || [format isEqualToString:FFGLPixelFormatARGB8888]) {
        return 4;
    } else if ([format isEqualToString:FFGLPixelFormatBGR888] || [format isEqualToString:FFGLPixelFormatRGB888]) {
        return 3;
    } else if ([format isEqualToString:FFGLPixelFormatBGR565] || [format isEqualToString:FFGLPixelFormatRGB565]) {
        return 2;
    } else {
        return 0;
    }
}
