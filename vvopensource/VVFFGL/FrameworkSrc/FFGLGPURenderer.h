//
//  FFGLGPURenderer.h
//  VVOpenSource
//
//  Created by Tom on 10/08/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FFGLRenderer.h"
#import <OpenGL/OpenGL.h>

typedef struct FFGLGPURendererData FFGLGPURendererData;

@interface FFGLGPURenderer : FFGLRenderer {
    FFGLGPURendererData *_data;
	
	CGLContextObj _context;		// prob a good idea to cache the context.
	GLuint _rectToSquareFBO;	// this FBO is responsible for providing the GL_TEXTURE_2D texture that FFGL requires.
	GLuint _squareFBOTexture;	// COLOR_ATTACHMENT_0 for our above FBO
	GLint _previousFBO;			// our previously bound FBO so when we pop out of one we dont mess up the stack.
}

@end
