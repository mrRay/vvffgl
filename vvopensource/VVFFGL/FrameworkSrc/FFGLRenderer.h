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
}

// for CPU effects/sources, the last two arguments can be nil.
//
// for GPU effects/sources, they are required.
// context should be set and stick around for the duration of the pluginRenderers lifetime
// if the context changes for whatever reason, probably should re-make the object
// need to pass in a viewport stuct

- (id)initWithPlugin:(FFGLPlugin *)plugin context:(CGLContextObj)context forBounds:(NSRect)bounds;
- (id)initWithPlugin:(FFGLPlugin *)plugin pixelFormat:(NSString *)format forBounds:(NSRect)bounds;
- (FFGLPlugin *)plugin;
- (CGLContextObj)context;
- (NSString *)pixelFormat;
- (NSRect)bounds;
- (id)valueForParameterKey:(NSString *)key;
- (void)setValue:(id)value forParameterKey:(NSString *)key;
- (void)renderAtTime:(NSTimeInterval)time;
@end
