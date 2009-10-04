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
}
- (id)initWithOpenGLContext:(NSOpenGLContext *)context pixelFormat:(NSString *)pixelFormat forBounds:(NSRect)bounds;
@property (retain, readonly) NSOpenGLContext *openGLContext;
@property (retain, readonly) NSString *pixelFormat;
@property (assign, readonly) NSRect bounds;
@property (retain, readwrite) FFGLRenderer *source;
@property (retain, readonly) NSArray *effects;
- (void)insertObject:(FFGLRenderer *)renderer inEffectsAtIndex:(NSUInteger)index;
- (void)removeObjectFromEffectsAtIndex:(NSUInteger)index;
- (void)renderAtTime:(NSTimeInterval)time;
@end
