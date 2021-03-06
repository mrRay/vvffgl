//
//  FFGLGPURenderer.h
//  VVOpenSource
//
//  Created by Tom on 10/08/2009.
//

#import <Cocoa/Cocoa.h>
#import "FFGLRenderer.h"
#import "FFGLInternal.h"
#import <OpenGL/OpenGL.h>
#import "FFGLPool.h"

@interface FFGLGPURenderer : FFGLRenderer {
@private
    FFGLProcessGLStruct _frameStruct;

    GLenum _textureTarget;
    GLuint _rendererFBO;		// this FBO is responsible for providing the GL_TEXTURE_2D texture that FFGL requires.
    GLuint _rendererDepthBuffer;	// depth buffer
    NSUInteger _textureWidth;
    NSUInteger _textureHeight;
#if defined(FFGL_USE_TEXTURE_POOLS)
    FFGLPoolRef _pool;
#endif
	//	GLuint _rendererFBOTexture;	// COLOR_ATTACHMENT_0 for our above FBO
}

@end
