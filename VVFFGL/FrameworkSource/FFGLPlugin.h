//
//  FFGLPlugin.h
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//

#import <Cocoa/Cocoa.h>

#pragma mark Constants

typedef NSUInteger FFGLPluginType;
enum {
    FFGLPluginTypeEffect = 0,
    FFGLPluginTypeSource = 1
};

#pragma mark Pixel-Formats

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

#pragma mark Plugin Attributes
extern NSString * const FFGLPluginAttributeNameKey;
extern NSString * const FFGLPluginAttributeVersionKey;
extern NSString * const FFGLPluginAttributeDescriptionKey;
extern NSString * const FFGLPluginAttributeIdentifierKey;
extern NSString * const FFGLPluginAttributeAuthorKey;
extern NSString * const FFGLPluginAttributePathKey;


#pragma mark Parameter Attributes
/*
 FFGLParameterAttributeTypeKey

	The object returned for this key is one of the following NSStrings:

		FFGLParameterTypeBoolean;
		FFGLParameterTypeEvent;
		FFGLParameterTypeNumber;
		FFGLParameterTypeString;
		FFGLParameterTypeImage;
 */
extern NSString * const FFGLParameterAttributeTypeKey;

/*
 FFGLParameterAttributeNameKey
 
	The object returned for this key is a NSString with the name of the parameter. This string should be used
	to describe the parameter in the user interface.
 */
extern NSString * const FFGLParameterAttributeNameKey;

/*
 FFGLParameterAttributeDefaultValueKey
 
	For boolean parameters, the object returned for this key is a NSNumber with a boolean value.
	For number paramaters, the object returned for this key is a NSNumber with a float value between 0.0 and 1.0.
	For string paramaters, the object returned for this key is a NSString.
 */
extern NSString * const FFGLParameterAttributeDefaultValueKey;

/*
 FFGLParameterAttributeMinimumValueKey
 
	For number parameters, the object returned for this key is a NSNumber with float value 0.0.
 */
extern NSString * const FFGLParameterAttributeMinimumValueKey;

/*
 FFGLParameterAttributeMaximumValueKey
 
	For number parameters, the object returned for this key is a NSNumber with float value 1.0.
 */
extern NSString * const FFGLParameterAttributeMaximumValueKey;

/*
 FFGLParameterAttributeRequiredKey
 
	For any parameter, the object returned for this key is a NSNumber with a bool value indicating
	if that parameter must be set for rendering to succeed. This value will always be YES for
	boolean, event, number or string inputs. Some image inputs may be optional.
 */
extern NSString * const FFGLParameterAttributeRequiredKey;

#pragma mark Parameter Types
extern NSString * const FFGLParameterTypeBoolean;
extern NSString * const FFGLParameterTypeEvent;
extern NSString * const FFGLParameterTypeNumber;
extern NSString * const FFGLParameterTypeString;
extern NSString * const FFGLParameterTypeImage;

typedef struct FFGLPluginData FFGLPluginData; // Private

@interface FFGLPlugin : NSObject <NSCopying> {
@private
    FFGLPluginData *_pluginData;
}

/*
 - (id)initWithPath:(NSString *)path

	Returns a FFGLPlugin for the FreeFrame plugin at path, if one exists.
	path should be the path to a FreeFrame plugin.
 */
 
- (id)initWithPath:(NSString *)path;

/*
 @property (readonly) FFGLPluginType type
	
	Returns one of
		FFGLPluginTypeEffect
		FFGLPluginTypeSource
	An effect plugin typically has one or more image parameter.
	A source plugin typically has no image parameters.
*/
@property (readonly) FFGLPluginType type;

/*
 @property (readonly) FFGLPluginMode mode
 
	Returns one of
		FFGLPluginModeCPU
		FFGLPluginModeGPU
	CPU-mode plugins run in main memory, GPU-mode plugins run on the graphics card.
 */
@property (readonly) FFGLPluginMode mode;

/*
 @property (readonly) NSArray *supportedBufferPixelFormats
 
	Returns an array of NSStrings indicating the pixel-formats supported. These may be some of
		FFGLPixelFormatARGB8888
		FFGLPixelFormatBGRA8888
		FFGLPixelFormatRGB888
		FFGLPixelFormatBGR888
		FFGLPixelFormatRGB565
		FFGLPixelFormatBGR565
 */
@property (readonly) NSArray *supportedBufferPixelFormats;

/*
 @property (readonly) NSDictionary *attributes
 
	Returns a dictionary with information about the plugin. The dictionary may have some or all
	of the following keys:
		FFGLPluginAttributeNameKey
		FFGLPluginAttributeVersionKey
		FFGLPluginAttributeDescriptionKey
		FFGLPluginAttributeIdentifierKey
		FFGLPluginAttributeAuthorKey
		FFGLPluginAttributePathKey
 */
@property (readonly) NSDictionary *attributes;

/*
 @property (readonly) NSArray *parameterKeys
	Returns an array of NSStrings representing the plugin's parameters.
 */
@property (readonly) NSArray *parameterKeys;

/*
 - (NSDictionary *)attributesForParameterWithKey:(NSString *)key
	
	Returns a dictionary with information about the parameter specified by key.
	See the FFGLParameterAttribute... constants, above, for a description of the
	contents of this dictionary.
	key should be one of the keys returned by parameterKeys.
 */
- (NSDictionary *)attributesForParameterWithKey:(NSString *)key;
@end
