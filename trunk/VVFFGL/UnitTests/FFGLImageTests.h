//
//  FFGLImageTests.h
//  VVFFGL
//
//  Created by Tom on 29/01/2010.
//  Copyright 2010 Tom Butterworth. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import <VVFFGL/VVFFGL.h>

@interface FFGLImageTests : SenTestCase {
	FFGLImage		*_image;
	void			*_pixelBuffer;
	CGLContextObj	_CGLContext;
	BOOL			*_bufferCalledback;
}

@end
