//
//  FFGLGPURenderer.h
//  VVOpenSource
//
//  Created by Tom on 10/08/2009.
//

#import <Cocoa/Cocoa.h>
#import "FFGLRenderer.h"
#import <OpenGL/OpenGL.h>

typedef struct FFGLGPURendererData FFGLGPURendererData;

@interface FFGLGPURenderer : FFGLRenderer {
    FFGLGPURendererData *_data;
	
	CGLContextObj _context;		// prob a good idea to cache the context. - superclass has it, should expose it, so [self context] would return it... but cache it if you like :)
	GLuint _rectToSquareFBO;	// this FBO is responsible for providing the GL_TEXTURE_2D texture that FFGL requires.
	GLuint _squareFBOTexture;	// COLOR_ATTACHMENT_0 for our above FBO
	GLint _previousFBO;			// our previously bound FBO so when we pop out of one we dont mess up the stack.
}

// render a rectangular texture (from QC, Core video etc) to a square texture for FFGL.
// bounds are the input texture coords for the rect texture.
- (GLuint) rectTextureToSquareTexture:(GLuint)inputTexture withCoords:(NSRect) rectCoords;

@end
