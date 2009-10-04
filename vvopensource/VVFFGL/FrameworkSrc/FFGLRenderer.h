//
//  FFGLRenderer.h
//  VVOpenSource
//
//  Created by Tom on 24/07/2009.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>

@class FFGLPlugin;

@interface FFGLRenderer : NSObject {
@private
    FFGLPlugin          *_plugin;
    uint32_t            _instance;
    CGLContextObj       _pluginContext;
    NSRect              _bounds;
    NSString            *_pixelFormat;
    NSMutableDictionary *_imageInputs;
    id                  _params;
}

// for CPU effects/sources, the last two arguments can be nil.
//
// for GPU effects/sources, they are required.
// context should be set and stick around for the duration of the pluginRenderers lifetime

- (id)initWithPlugin:(FFGLPlugin *)plugin context:(CGLContextObj)context forBounds:(NSRect)bounds;
- (id)initWithPlugin:(FFGLPlugin *)plugin pixelFormat:(NSString *)format forBounds:(NSRect)bounds;
- (FFGLPlugin *)plugin;
- (CGLContextObj)context;
- (NSString *)pixelFormat;
- (NSRect)bounds;
- (id)valueForParameterKey:(NSString *)key;
- (void)setValue:(id)value forParameterKey:(NSString *)key;
/*
 - (id)parameters
    Returns an object interested parties can bind to to get/set parameter values. Bind to anObject.parameters.key.
 */
- (id)parameters;
- (void)renderAtTime:(NSTimeInterval)time;
// TODO: some way of setting the target image, once we have our own image class to handle both pixel-buffers and textures.
// At present this functionality is in the CPU/GPU subclasses.
@end
