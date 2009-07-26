//
//  vvFFGLPlugin.m
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import "VVFFGLPlugin.h"
#import "FreeFrame.h"
#import "FFGL.h"

struct VVFFGLPluginData {
    CFBundleRef bundle;
    FF_Main_FuncPtr main;
    Boolean initted;
    VVFFGLPluginMode mode;
    NSArray *bufferPixelFormats;
    NSDictionary *parameters;
    PluginInfoStruct *info;
    PluginExtendedInfoStruct *extendedInfo;
};

NSString * const VVFFGLPluginBufferPixelFormatARGB8888 = @"VVFFGLPluginBufferPixelFormatARGB8888";
NSString * const VVFFGLPluginBufferPixelFormatBGRA8888 = @"VVFFGLPluginBufferPixelFormatBGRA8888";
NSString * const VVFFGLPluginBufferPixelFormatRGB888 = @"VVFFGLPluginBufferPixelFormatRGB888";
NSString * const VVFFGLPluginBufferPixelFormatBGR888 = @"VVFFGLPluginBufferPixelFormatBGR888";
NSString * const VVFFGLPluginBufferPixelFormatRGB565 = @"VVFFGLPluginBufferPixelFormatRGB565";
NSString * const VVFFGLPluginBufferPixelFormatBGR565 = @"VVFFGLPluginBufferPixelFormatBGR565";

NSString * const VVFFGLPluginAttributesNameKey = @"VVFFGLPluginAttributesNameKey";
NSString * const VVFFGLPluginAttributesVersionKey = @"VVFFGLPluginAttributesVersionKey";
NSString * const VVFFGLPluginAttributesDescriptionKey = @"VVFFGLPluginAttributesDescriptionKey";
NSString * const VVFFGLPluginAttributesAuthorKey = @"VVFFGLPluginAttributesAuthorKey";

NSString * const VVFFGLParameterAttributeTypeKey = @"VVFFGLParameterAttributeTypeKey";
NSString * const VVFFGLParameterAttributeNameKey = @"VVFFGLParameterAttributeNameKey";
NSString * const VVFFGLParameterAttributeDefaultValueKey = @"VVFFGLParameterAttributeDefaultValueKey";
NSString * const VVFFGLParameterAttributeMinimumValueKey = @"VVFFGLParameterAttributeMinimumValueKey";
NSString * const VVFFGLParameterAttributeMaximumValueKey = @"VVFFGLParameterAttributeMaximumValueKey";
NSString * const VVFFGLParameterAttributeRequiredKey = @"VVFFGLParameterAttributeRequiredKey";

NSString * const VVFFGLParameterTypeBoolean = @"VVFFGLParameterTypeBoolean";
NSString * const VVFFGLParameterTypeEvent = @"VVFFGLParameterTypeEvent";
NSString * const VVFFGLParameterTypePoint = @"VVFFGLParameterTypePoint";
NSString * const VVFFGLParameterTypeNumber = @"VVFFGLParameterTypeNumber";
NSString * const VVFFGLParameterTypeString = @"VVFFGLParameterTypeString";
NSString * const VVFFGLParameterTypeColor = @"VVFFGLParameterTypeColor";
NSString * const VVFFGLParameterTypeImage = @"VVFFGLParameterTypeImage";


@implementation VVFFGLPlugin

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithPath:(NSString *)path
{
    if (self = [super init]) {
        
        _pluginData = malloc(sizeof(struct VVFFGLPluginData));
        if (_pluginData == NULL) {
            [self release];
            return nil;
        }
        // Set everything we need in dealloc, in case we bail from init.
        _pluginData->initted = false;
        _pluginData->bundle = NULL;
        _pluginData->bufferPixelFormats = nil;
        _pluginData->parameters = nil;
        
        // Load the plugin bundle.
        NSURL *url = [NSURL fileURLWithPath:path isDirectory:NO];
        if (url == nil) {
            [self release];
            return nil;
        }
        _pluginData->bundle = CFBundleCreate(kCFAllocatorDefault, (CFURLRef)url);
        if (_pluginData->bundle == NULL) {
            [self release];
            return nil;
        }
        
        // Get a pointer to the function.
        _pluginData->main = CFBundleGetFunctionPointerForName(_pluginData->bundle, CFSTR("plugMain"));
        if (_pluginData->main == NULL) {
            [self release];
            return nil;
        }

        // Get basic plugin info, and check we are a type (source or effect) we know about.
        plugMainUnion result;
        result = _pluginData->main(FF_GETINFO, 0, 0);
        if (result.svalue == NULL) {
            [self release];
            return nil;
        }
        _pluginData->info = (PluginInfoStruct *)result.svalue;
        if ((_pluginData->info->PluginType != FF_SOURCE) && (_pluginData->info->PluginType != FF_EFFECT)) {
            // Bail if this is some future other type of plugin.
            [self release];
            return nil;
        }
        
        // Get extended info, which is used by our -attributes method.
        result = _pluginData->main(FF_GETEXTENDEDINFO, 0, 0);
        if (result.svalue == NULL) {
            // Bail, but do we have to? Could be a bit more elegant dealing with this, which isn't a catastrophic problem.
            [self release];
            return nil;
        }
        _pluginData->extendedInfo = (PluginExtendedInfoStruct *)result.svalue;
        
        // Determine our mode.
        result = _pluginData->main(FF_GETPLUGINCAPS, FF_CAP_PROCESSOPENGL, 0);
        if (result.ivalue == FF_SUPPORTED) {
            _pluginData->mode = VVFFGLPluginModeGPU;
        } else {
            _pluginData->mode = VVFFGLPluginModeCPU;
        }
        
        /*
         Get information about the pixel formats we support. FF plugins only support native-endian pixel formats. We could
         support both and handle conversion, however that doesn't seem a priority.
         */
        _pluginData->bufferPixelFormats = [[NSMutableArray alloc] initWithCapacity:3];
        result = _pluginData->main(FF_GETPLUGINCAPS, FF_CAP_16BITVIDEO, 0);
        if (result.ivalue == FF_SUPPORTED) {
#if __BIG_ENDIAN__
            [(NSMutableArray *)_pluginData->bufferPixelFormats addObject:VVFFGLPluginBufferPixelFormatRGB565];
#else
            [(NSMutableArray *)_pluginData->bufferPixelFormats addObject:VVFFGLPluginBufferPixelFormatBGR565];
#endif
        }
        result = _pluginData->main(FF_GETPLUGINCAPS, FF_CAP_24BITVIDEO, 0);
        if (result.ivalue == FF_SUPPORTED) {
#if __BIG_ENDIAN__
            [(NSMutableArray *)_pluginData->bufferPixelFormats addObject:VVFFGLPluginBufferPixelFormatRGB888];
#else
            [(NSMutableArray *)_pluginData->bufferPixelFormats addObject:VVFFGLPluginBufferPixelFormatBGR888];
#endif
        }
        result = _pluginData->main(FF_GETPLUGINCAPS, FF_CAP_32BITVIDEO, 0);
        if (result.ivalue == FF_SUPPORTED) {
#if __BIG_ENDIAN__
            [(NSMutableArray *)_pluginData->bufferPixelFormats addObject:VVFFGLPluginBufferPixelFormatARGB8888];
#else
            [(NSMutableArray *)_pluginData->bufferPixelFormats addObject:VVFFGLPluginBufferPixelFormatBGRA8888];
#endif
        }
        
        // Discover our parameters, which include the plugin's parameters plus video inputs.
        _pluginData->parameters = [[NSMutableDictionary alloc] initWithCapacity:4];
        NSUInteger i = 0;
        NSDictionary *attributes;
        NSString *name;
        result = _pluginData->main(FF_GETPLUGINCAPS, FF_CAP_MINIMUMINPUTFRAMES, 0);
        for (i = 0; i < result.ivalue; i++) {
            name = [NSString stringWithFormat:@"Input Image #%u", i];
            attributes = [NSDictionary dictionaryWithObjectsAndKeys:VVFFGLParameterTypeImage, VVFFGLParameterAttributeTypeKey,
                          name, VVFFGLParameterAttributeNameKey, [NSNumber numberWithBool:YES], VVFFGLParameterAttributeRequiredKey, nil];
            [(NSMutableDictionary *)_pluginData->parameters setObject:attributes forKey:name];
        }
        result = _pluginData->main(FF_GETPLUGINCAPS, FF_CAP_MAXIMUMINPUTFRAMES, 0);
        for (; i < result.ivalue; i++) {
            name = [NSString stringWithFormat:@"Input Image #%u", i];
            attributes = [NSDictionary dictionaryWithObjectsAndKeys:VVFFGLParameterTypeImage, VVFFGLParameterAttributeTypeKey,
                          name, VVFFGLParameterAttributeNameKey, [NSNumber numberWithBool:NO], VVFFGLParameterAttributeRequiredKey, nil];
            [(NSMutableDictionary *)_pluginData->parameters setObject:attributes forKey:name];
        }
        result = _pluginData->main(FF_GETNUMPARAMETERS, 0, 0);
        for (i = 0; i < result.ivalue; i++) {
            // TODO: finishing populating parameters...
        }
        
        // Finally initialise the plugin.
        result = _pluginData->main(FF_INITIALISE, 0, 0);
        if (result.ivalue != FF_SUCCESS) {
            [self release];
            return nil;
        }
        _pluginData->initted = true;
    }
    return self;
}

- (void)dealloc
{
    if (_pluginData != NULL) {
        if (_pluginData->initted == true)
            _pluginData->main(FF_DEINITIALISE, 0, 0);
        if (_pluginData->bundle)
            CFRelease(_pluginData->bundle);
        [_pluginData->bufferPixelFormats release];
        [_pluginData->parameters release];
        free(_pluginData);
    }
    [super dealloc];
}

- (VVFFGLPluginType)type
{
    return _pluginData->info->PluginType;
}

- (VVFFGLPluginMode)mode
{
    return _pluginData->mode;
}

- (NSArray *)supportedBufferPixelFormats
{
    return _pluginData->bufferPixelFormats;
}

- (NSString *)identifier
{
    return [[[NSString alloc] initWithBytes:_pluginData->info->PluginUniqueID length:4 encoding:NSASCIIStringEncoding] autorelease];
}

- (NSDictionary *)attributes
{
    NSString *name;
    if(_pluginData->info->PluginName)
        name = [[[NSString alloc] initWithBytes:_pluginData->info->PluginName length:16 encoding:NSASCIIStringEncoding] autorelease];
    else
        name = [self identifier];
    
    NSNumber *version = [NSNumber numberWithFloat:_pluginData->extendedInfo->PluginMajorVersion + (_pluginData->extendedInfo->PluginMinorVersion * 0.001)];
    
    NSString *description;
    if (_pluginData->extendedInfo->Description)
        description = [NSString stringWithCString:_pluginData->extendedInfo->Description encoding:NSASCIIStringEncoding];
    else
        description = @"";
    
    NSString *author;
    if (_pluginData->extendedInfo->About)
        author = [NSString stringWithCString:_pluginData->extendedInfo->About encoding:NSASCIIStringEncoding];
    else
        author = @"";
    
    return [NSDictionary dictionaryWithObjectsAndKeys:name, VVFFGLPluginAttributesNameKey, version, VVFFGLPluginAttributesVersionKey,
            description, VVFFGLPluginAttributesDescriptionKey, author, VVFFGLPluginAttributesAuthorKey, nil];
}

- (NSArray *)parameterKeys
{
    return [_pluginData->parameters allKeys];
}

- (NSDictionary *)attributesForParameterWithKey:(NSString *)key
{
    return [_pluginData->parameters objectForKey:key];
}
@end
