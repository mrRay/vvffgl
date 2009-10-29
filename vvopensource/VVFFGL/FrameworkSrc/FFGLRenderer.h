//
//  FFGLRenderer.h
//  VVOpenSource
//
//  Created by Tom on 24/07/2009.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
#import <pthread.h> // maybe obscure our ivars in a struct and move this to the .m?

@class FFGLPlugin, FFGLImage;

@interface FFGLRenderer : NSObject {
@private
    FFGLPlugin          *_plugin;
    void		*_instance;
    CGLContextObj       _pluginContext;
    NSRect              _bounds;
    NSString            *_pixelFormat;
    NSMutableDictionary *_imageInputs;
    BOOL                _needsToCheckValidity;
    BOOL                *_imageInputValidity;
    FFGLImage           *_output;
    id                  _params;
    pthread_mutex_t     _lock;
    
}
// or one long init to support both
- (id)initWithPlugin:(FFGLPlugin *)plugin context:(CGLContextObj)context forBounds:(NSRect)bounds;
- (id)initWithPlugin:(FFGLPlugin *)plugin pixelFormat:(NSString *)format forBounds:(NSRect)bounds;
- (FFGLPlugin *)plugin;
- (CGLContextObj)context;
- (NSString *)pixelFormat;
- (NSRect)bounds;
/*
 - (BOOL)willUseParameterKey:(NSString *)key
    A plugin may ignore some of its image parameters under certain conditions. Use this method to discover if an input
    will be used with the parameters in their current state.
 */
- (BOOL)willUseParameterKey:(NSString *)key;
- (id)valueForParameterKey:(NSString *)key;
- (void)setValue:(id)value forParameterKey:(NSString *)key;
/*
 - (id)parameters
    Returns an object interested parties can bind to to get/set parameter values. Bind to aRenderer.parameters.aKey
 */
- (id)parameters;
- (FFGLImage *)outputImage;
- (BOOL)renderAtTime:(NSTimeInterval)time;
@end
