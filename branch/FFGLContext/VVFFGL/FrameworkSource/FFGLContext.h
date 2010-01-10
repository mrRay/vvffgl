//
//  FFGLContext.h
//  VVFFGL
//
//  Created by Tom on 12/11/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>

typedef struct FFGLContextPrivate FFGLContextPrivate;

@interface FFGLContext : NSObject {
	FFGLContextPrivate *_priv;
}
- (id)initWithCGLContext:(CGLContextObj)context pixelFormat:(NSString *)pixelFormat size:(NSSize)size;
- (CGLContextObj)CGLContextObj;
- (NSString *)pixelFormat;
- (NSSize)size;
@end
