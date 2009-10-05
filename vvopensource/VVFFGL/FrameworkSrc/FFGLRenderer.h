//
//  FFGLRenderer.h
//  VVOpenSource
//
//  Created by Tom on 24/07/2009.
//

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>
//#import <pthread.h> // maybe obscure our ivars in a struct and move this to the .m?

@class FFGLPlugin, FFGLImage;

@interface FFGLRenderer : NSObject {
@private
    FFGLPlugin          *_plugin;
    uint32_t            _instance;
    CGLContextObj       _pluginContext;
    NSRect              _bounds;
    NSString            *_pixelFormat;
    NSMutableDictionary *_imageInputs;
    FFGLImage           *_output;
    id                  _params;
//    pthread_mutex_t     _lock; // coming
    
}
// or one long init to support both
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
    Returns an object interested parties can bind to to get/set parameter values. Bind to anObject.parameters.key.value.
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
- (void)renderAtTime:(NSTimeInterval)time;
@end
