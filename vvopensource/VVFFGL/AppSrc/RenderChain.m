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
@synthesize output = _output;

- (FFGLRenderer *)source
{
    [_lock lock];
    FFGLRenderer *s = _source;
    [_lock unlock];
    return s;
}

- (void)setSource:(FFGLRenderer *)source
{
    [self willChange:NSKeyValueChangeReplacement valuesAtIndexes:[NSIndexSet indexSetWithIndex:0] forKey:@"completeChain"];
    [_lock lock];
    [source retain];
    [_source release];
    _source = source;
    [_lock unlock];
    [self didChange:NSKeyValueChangeReplacement valuesAtIndexes:[NSIndexSet indexSetWithIndex:0] forKey:@"completeChain"];
}

- (NSArray *)effects
{
    [_lock lock];
    NSArray *e = [NSArray arrayWithArray:_effects];
    [_lock unlock];
    return e; // return a copy to preserve our thread-safety
}

- (void)insertObject:(FFGLRenderer *)renderer inEffectsAtIndex:(NSUInteger)index
{
    [self willChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:index + 1] forKey:@"completeChain"];
    [_lock lock];
    [_effects insertObject:renderer atIndex:index];
    [_lock unlock];
    [self didChange:NSKeyValueChangeInsertion valuesAtIndexes:[NSIndexSet indexSetWithIndex:index + 1] forKey:@"completeChain"];
}

- (void)removeObjectFromEffectsAtIndex:(NSUInteger)index
{
    [self willChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:index + 1] forKey:@"completeChain"];
    [_lock lock];
    [_effects removeObjectAtIndex:index];
    [_lock unlock];
    [self didChange:NSKeyValueChangeRemoval valuesAtIndexes:[NSIndexSet indexSetWithIndex:index + 1] forKey:@"completeChain"];
}

- (NSArray *)completeChain
{
    [_lock lock];
    NSArray *result = [[NSArray arrayWithObject:(_source != nil ? (id)_source : (id)[NSNull null])] arrayByAddingObjectsFromArray:_effects];
    [_lock unlock];
    return result;
}

- (void)insertObject:(FFGLRenderer *)renderer inCompleteChainAtIndex:(NSUInteger)index {
    if (index == 0) {
        [self setSource:renderer];
    } else {
        [self insertObject:renderer inEffectsAtIndex:index - 1];
    }
}

- (void)removeObjectFromCompleteChainAtIndex:(NSUInteger)index {
    if (index == 0) {
        [self setSource:nil];
    } else {
        [self removeObjectFromEffectsAtIndex:index - 1];
    }
}

- (void)renderAtTime:(NSTimeInterval)time
{
    [self willChangeValueForKey:@"output"];
    [_lock lock];
    if (_source) {
        BOOL result;
        result = [_source renderAtTime:time];
        if (result == NO) {
//            NSLog(@"Render failed");
        }
        FFGLImage *image = [_source outputImage];
        if (image == nil) {
//            NSLog(@"No output from source.");
            [_output release];
            _output = nil;
            [_lock unlock];
            return;
        }
        for (FFGLRenderer *effect in _effects) {
            NSArray *parameters = [[effect plugin] parameterKeys];
            for (NSString *key in parameters) {
                if ([[[[effect plugin] attributesForParameterWithKey:key] objectForKey:FFGLParameterAttributeTypeKey] isEqualToString:FFGLParameterTypeImage]) {
                    [effect setValue:image forParameterKey:key];
                    break;
                }
            }
            result = [effect renderAtTime:time];
            if (result == NO) {
//                NSLog(@"Render failed");
            }
            image = [effect outputImage];
        }
        [image retain];
        [_output release];
        _output = image;
    }
    [_lock unlock];
    [self didChangeValueForKey:@"output"];
}
@end
