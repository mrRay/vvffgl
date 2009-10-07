//
//  RenderChain.h
//  VVOpenSource
//
//  Created by Tom on 18/09/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <VVFFGL/VVFFGL.h>

@interface RenderChain : NSObject {
@private
    NSOpenGLContext *_context;
    NSString        *_pixelFormat;
    NSRect          _bounds;
    FFGLRenderer    *_source;
    NSMutableArray  *_effects;
    NSLock          *_lock;
    FFGLImage       *_output;
}
- (id)initWithOpenGLContext:(NSOpenGLContext *)context pixelFormat:(NSString *)pixelFormat forBounds:(NSRect)bounds;
@property (readonly) NSOpenGLContext *openGLContext;
@property (readonly) NSString *pixelFormat;
@property (readonly) NSRect bounds;
@property (retain, readwrite) FFGLRenderer *source;
@property (readonly) NSArray *effects;
@property (readonly) FFGLImage *output;
- (void)insertObject:(FFGLRenderer *)renderer inEffectsAtIndex:(NSUInteger)index;
- (void)removeObjectFromEffectsAtIndex:(NSUInteger)index;
- (void)renderAtTime:(NSTimeInterval)time;
@end
