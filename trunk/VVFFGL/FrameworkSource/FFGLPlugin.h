//
//  FFGLPlugin.h
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//

#import <Cocoa/Cocoa.h>

#pragma mark Constants

/**
@defgroup FFGLPluginConstants
@{
*/




/**
Used to distinguish between effects and sources.
*/
typedef enum {
    FFGLPluginTypeEffect = 0,	/*!<	the plugin is an effect- it operates as a filter on passed images	*/
    FFGLPluginTypeSource = 1,	/*!<	the plugin is a source- it generates images	*/
} FFGLPluginType;

#pragma mark Pixel-Formats

extern NSString * const FFGLPixelFormatARGB8888;	/*!<	defines a 32-bit ARGB pixel format	*/
extern NSString * const FFGLPixelFormatBGRA8888;	/*!<	defines a 32-bit BGRA pixel format	*/
extern NSString * const FFGLPixelFormatRGB888;	/*!<	defines a 24-bit RGB pixel foramt	*/
extern NSString * const FFGLPixelFormatBGR888;	/*!<	defines a 24-bit BGR pixel format	*/
extern NSString * const FFGLPixelFormatRGB565;	/*!<	defines a 16-bit RGB pixel format	*/
extern NSString * const FFGLPixelFormatBGR565;	/*!<	defines a 16-bit BGR pixel format	*/

/**
Used to distinguish between plugin rendering modes (CPU vs GPU)
*/
typedef enum {
    FFGLPluginModeCPU = 0,	/*!<	the plugin is processing image data on the CPU (freeframe 1.0)	*/
    FFGLPluginModeGPU = 1	/*!<	the plugin is processing image data on the GPU (freeframe 1.5/freeframe gl)	*/
} FFGLPluginMode;

#pragma mark Plugin Attributes

extern NSString * const FFGLPluginAttributeNameKey;	/*!<	the object returned for this key is an NSString		*/
extern NSString * const FFGLPluginAttributeDescriptionKey;	/*!<	the object returned for this key is an NSString		*/
extern NSString * const FFGLPluginAttributeAuthorKey;	/*!<	the object returned for this key is an NSString		*/
extern NSString * const FFGLPluginAttributePathKey;	/*!<	the object returned for this key is an NSString		*/
extern NSString * const FFGLPluginAttributeIdentifierKey;	/*!<	returns an NSString four characters long.  it is possible two different freeframe plugins could return the same identifier, so it should not be depended on to determine identity.		*/
extern NSString * const FFGLPluginAttributeMajorVersionKey;	/*!<	returns an NSNumber with integer values representing the major and minor versions of the plugin.	*/
extern NSString * const FFGLPluginAttributeMinorVersionKey;	/*!<	returns an NSNumber with integer values representing the major and minor versions of the plugin.	*/

#pragma mark Parameter Attributes

extern NSString * const FFGLParameterAttributeTypeKey;	/*!<	returns an object which is one of the following strings: FFGLParameterTypeBoolean, FFGLParameterTypeEvent, FFGLParameterTypeNumber, FFGLParameterTypeString, FFGLParameterTypeImage		*/

/*!
The object returned for this key is a NSString with the name of the parameter. This string should be used to describe the parameter in the user interface.
 */
extern NSString * const FFGLParameterAttributeNameKey;

/*!
Describes the default value for a given parameter key
- For boolean parameters, the object returned for this key is a NSNumber with a boolean value.
- For number paramaters, the object returned for this key is a NSNumber with a float value between 0.0 and 1.0.
- For string paramaters, the object returned for this key is a NSString.
 */
extern NSString * const FFGLParameterAttributeDefaultValueKey;

/*!
For number parameters, the object returned for this key is a NSNumber with float value 0.0.
 */
extern NSString * const FFGLParameterAttributeMinimumValueKey;

/*!
For number parameters, the object returned for this key is a NSNumber with float value 1.0.
 */
extern NSString * const FFGLParameterAttributeMaximumValueKey;

/*!
For any parameter, the object returned for this key is a NSNumber with a bool value indicating if that parameter must be set for rendering to succeed. This value will always be YES for boolean, event, number or string inputs. Some image inputs may be optional.
 */
extern NSString * const FFGLParameterAttributeRequiredKey;

#pragma mark Parameter Types

extern NSString * const FFGLParameterTypeBoolean;	/*!<	A boolean parameter type	*/
extern NSString * const FFGLParameterTypeEvent;		/*!<	An event-type parameter		*/
extern NSString * const FFGLParameterTypeNumber;	/*!<	A number-type parameter	*/
extern NSString * const FFGLParameterTypeString;	/*!<	A string-type parameter	*/
extern NSString * const FFGLParameterTypeImage;		/*!<	An image-type parameter	*/




/*!
@}
*/




///	A single instance of a FF or FFGL plugin
/*!
An instance of FFGLPlugin is created by loading a file at a specified path (or by using FFGLPluginManager, but that's discussed elsewhere).  Each freeframe "effect" you load has its own instance of FFGLPlugin behind it- the FFGLPlugin must exist for the lifetime off the effect (FFGLRenderer, which is really the "main" class in this framework, automatically retains the plugin used to create it).
<BR><BR>Several plugin-related constants used by various methods are listed in the @ref FFGLPluginConstants section.
*/
@interface FFGLPlugin : NSObject <NSCopying> {
@private
    void *_pluginPrivate;
}

/*!
	Returns a FFGLPlugin for the FreeFrame plugin at path, if one exists.
	path should be the path to a FreeFrame plugin.
 */
 
- (id)initWithPath:(NSString *)path;

/*!
	Returns one of
		FFGLPluginTypeEffect
		FFGLPluginTypeSource
	An effect plugin typically has one or more image parameter.
	A source plugin typically has no image parameters.
*/
@property (readonly) FFGLPluginType type;

/*!
	Returns one of
		FFGLPluginModeCPU
		FFGLPluginModeGPU
	CPU-mode plugins run in main memory, GPU-mode plugins run on the graphics card.
 */
@property (readonly) FFGLPluginMode mode;

/*!
	Returns an array of NSStrings indicating the pixel-formats supported. These may be some of
		FFGLPixelFormatARGB8888
		FFGLPixelFormatBGRA8888
		FFGLPixelFormatRGB888
		FFGLPixelFormatBGR888
		FFGLPixelFormatRGB565
		FFGLPixelFormatBGR565
 */
@property (readonly) NSArray *supportedBufferPixelFormats;

/*!
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

/*!
	Returns an array of NSStrings representing the plugin's parameters.
 */
@property (readonly) NSArray *parameterKeys;

/*!
	Returns a dictionary with information about the parameter specified by key.  See the FFGLParameterAttribute... constants, above, for a description of the contents of this dictionary.
	@param key should be one of the keys returned by parameterKeys.
 */
- (NSDictionary *)attributesForParameterWithKey:(NSString *)key;
@end
