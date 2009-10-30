//
//  FFGLPlugin.h
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//

#import <Cocoa/Cocoa.h>

typedef NSUInteger FFGLPluginType;
enum {
    FFGLPluginTypeEffect = 0,
    FFGLPluginTypeSource = 1
};

extern NSString * const FFGLPixelFormatARGB8888;
extern NSString * const FFGLPixelFormatBGRA8888;
extern NSString * const FFGLPixelFormatRGB888;
extern NSString * const FFGLPixelFormatBGR888;
extern NSString * const FFGLPixelFormatRGB565;
extern NSString * const FFGLPixelFormatBGR565;

typedef NSUInteger FFGLPluginMode;
enum {
    FFGLPluginModeCPU = 0,
    FFGLPluginModeGPU = 1
};

extern NSString * const FFGLPluginAttributeNameKey;
extern NSString * const FFGLPluginAttributeVersionKey;
extern NSString * const FFGLPluginAttributeDescriptionKey;
extern NSString * const FFGLPluginAttributeIdentifierKey;
extern NSString * const FFGLPluginAttributeAuthorKey;
extern NSString * const FFGLPluginAttributePathKey;

extern NSString * const FFGLParameterAttributeTypeKey;
extern NSString * const FFGLParameterAttributeNameKey;
extern NSString * const FFGLParameterAttributeDefaultValueKey; // For Boolean, Number & String types.
extern NSString * const FFGLParameterAttributeMinimumValueKey; // For Number types.
extern NSString * const FFGLParameterAttributeMaximumValueKey; // For Number types.
extern NSString * const FFGLParameterAttributeRequiredKey; // A NSNumber with a BOOL value.

extern NSString * const FFGLParameterTypeBoolean; // A NSNumber with a BOOL value.
extern NSString * const FFGLParameterTypeEvent; // A NSNumber with a BOOL value.
extern NSString * const FFGLParameterTypeNumber; // A NSNumber between 0.0 and 1.0.
extern NSString * const FFGLParameterTypeString; // A NSString.
extern NSString * const FFGLParameterTypeImage; // A FFGLImage.

typedef struct FFGLPluginData FFGLPluginData; // Private

@interface FFGLPlugin : NSObject <NSCopying>{
@private
    FFGLPluginData *_pluginData;
}
- (id)initWithPath:(NSString *)path;
- (FFGLPluginType)type;
- (FFGLPluginMode)mode;
- (NSArray *)supportedBufferPixelFormats; // An NSArray of NSStrings. 
- (NSDictionary *)attributes;
- (NSArray *)parameterKeys;
- (NSDictionary *)attributesForParameterWithKey:(NSString *)key;
@end
