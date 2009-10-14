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
    uint32_t            _instance;
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
    Returns an object interested parties can bind to to get/set parameter values. Bind to anObject.parameters.aKey
 */
- (id)parameters;

/*
 
 Output
 
 Either
    we have one outputImage method, and create a new image every renderAtTime:
        Advantage - FFGLImage remains truly immutable, so if you're using output downstream, you can be sure it won't change.
 Or
    we have a setRenderDestination: method, and reuse the same image until it is changed.
        Advantage - If clients have simple linear pipelines and can only call this once, this avoids constant reallocation of resources.
 Or
    some other solution I haven't thought of
 
 Thoughts?
 
 //- (void)setRenderDestination:(FFGLImage *)image;
 //- (FFGLImage *)renderDestination;
 
 */
- (FFGLImage *)outputImage;
- (BOOL)renderAtTime:(NSTimeInterval)time;
@end
