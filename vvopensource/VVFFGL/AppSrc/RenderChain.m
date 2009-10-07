//
//  RenderChain.m
//  VVOpenSource
//
//  Created by Tom on 18/09/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import "RenderChain.h"


@implementation RenderChain
- (id)init {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithOpenGLContext:(NSOpenGLContext *)context pixelFormat:(NSString *)pixelFormat forBounds:(NSRect)bounds
{
    if (self = [super init]) {
        _context = [context retain];
        _pixelFormat = [pixelFormat retain];
        _bounds = bounds;
        _lock = [[NSLock alloc] init];
        _effects = [[NSMutableArray alloc] initWithCapacity:2];
    }
    return self;    
}

- (void)dealloc
{
    [_context release];
    [_pixelFormat release];
    [_source release];
    [_effects release];
    [_lock release];
    [super dealloc];
}

@synthesize pixelFormat = _pixelFormat;
@synthesize openGLContext = _context;
@synthesize bounds = _bounds;
@synthesize source = _source;
@synthesize output = _output;

- (NSArray *)effects
{
    [_lock lock];
    NSArray *output = [NSArray arrayWithArray:_effects];
    [_lock unlock];
    return output; // return a copy to preserve our thread-safety
}

- (void)insertObject:(FFGLRenderer *)renderer inEffectsAtIndex:(NSUInteger)index
{
    [_lock lock];
    [_effects insertObject:renderer atIndex:index];
    [_lock unlock];
}

- (void)removeObjectFromEffectsAtIndex:(NSUInteger)index
{
    [_lock lock];
    [_effects removeObjectAtIndex:index];
    [_lock unlock];
}


- (void)renderAtTime:(NSTimeInterval)time
{
    [_lock lock];
    if (_source) {
        [self willChangeValueForKey:@"output"];
        [_source renderAtTime:time];
        _output = [_source outputImage];
        for (FFGLRenderer *effect in _effects) {
            NSArray *parameters = [[effect plugin] parameterKeys];
            for (NSString *key in parameters) {
                if ([[[[effect plugin] attributesForParameterWithKey:key] objectForKey:FFGLParameterAttributeTypeKey] isEqualToString:FFGLParameterTypeImage]) {
                    [effect setValue:_output forParameterKey:key];
                    break;
                }
            }
            [effect renderAtTime:time];
            _output = [effect outputImage];
        }
        [self didChangeValueForKey:@"output"];
    }
    [_lock unlock];
}
@end
