//
//  FFGLRendererTests.h
//  VVFFGL
//
//  Created by Tom on 30/01/2010.
//  Copyright 2010 Tom Butterworth. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import <OpenGL/OpenGL.h>
#import <VVFFGL/VVFFGL.h>

@interface FFGLRendererTests : SenTestCase {
	CGLContextObj _CGLContext;
	FFGLRenderer *_renderer;
}

@end
