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

// The following is a mess so we can easily *change* the source from the interface and *add* effects.
// This app probably shouldn't be an example app... let's keep the QCPlugin for that :/
@property (retain, readwrite) FFGLRenderer *source;
@property (readonly) NSArray *effects;
- (void)insertObject:(FFGLRenderer *)renderer inEffectsAtIndex:(NSUInteger)index;
- (void)removeObjectFromEffectsAtIndex:(NSUInteger)index;
@property (readonly) NSArray *completeChain;
- (void)insertObject:(FFGLRenderer *)renderer inCompleteChainAtIndex:(NSUInteger)index;
- (void)removeObjectFromCompleteChainAtIndex:(NSUInteger)index;
// Render/output
- (void)renderAtTime:(NSTimeInterval)time;
@property (readonly) FFGLImage *output;
@end
