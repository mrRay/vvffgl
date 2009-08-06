//
//  vvFFGLPlugin.m
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import "VVFFGLPlugin.h"
#import "VVFFGLPluginInstances.h"
#import "FreeFrame.h"
#import "FFGL.h"

struct VVFFGLPluginData {
    CFBundleRef bundle;
    FF_Main_FuncPtr main;
    Boolean initted;
    VVFFGLPluginType type;
    VVFFGLPluginMode mode;
    NSArray *bufferPixelFormats;
    NSDictionary *parameters;
    NSDictionary *attributes;
    NSString *identifier;
};

NSString * const VVFFGLPluginBufferPixelFormatARGB8888 = @"VVFFGLPluginBufferPixelFormatARGB8888";
NSString * const VVFFGLPluginBufferPixelFormatBGRA8888 = @"VVFFGLPluginBufferPixelFormatBGRA8888";
NSString * const VVFFGLPluginBufferPixelFormatRGB888 = @"VVFFGLPluginBufferPixelFormatRGB888";
NSString * const VVFFGLPluginBufferPixelFormatBGR888 = @"VVFFGLPluginBufferPixelFormatBGR888";
NSString * const VVFFGLPluginBufferPixelFormatRGB565 = @"VVFFGLPluginBufferPixelFormatRGB565";
NSString * const VVFFGLPluginBufferPixelFormatBGR565 = @"VVFFGLPluginBufferPixelFormatBGR565";

NSString * const VVFFGLPluginAttributeNameKey = @"VVFFGLPluginAttributesNameKey";
NSString * const VVFFGLPluginAttributeVersionKey = @"VVFFGLPluginAttributesVersionKey";
NSString * const VVFFGLPluginAttributeDescriptionKey = @"VVFFGLPluginAttributesDescriptionKey";
NSString * const VVFFGLPluginAttributeAuthorKey = @"VVFFGLPluginAttributesAuthorKey";
NSString * const VVFFGLPluginAttributePathKey = @"VVFFGLPluginAttributePathKey";

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
        _pluginData->attributes = nil;
        _pluginData->identifier = nil;
        
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
        PluginInfoStruct *info = (PluginInfoStruct *)result.svalue;
        if ((info->PluginType != FF_SOURCE) && (info->PluginType != FF_EFFECT)) {
            // Bail if this is some future other type of plugin.
            [self release];
            return nil;
        }
        
        /*
         Long init
            Current strategy is to do all our parameter/attributes calls to the plugin at init, so we can give that information out without locks
            because we won't be changing anything in memory after init... Can change if it proves problematic, in which case the below will move
            to respective methods.
         */
        
        // Set our identifier and type from the PluginInfoStruct.
        _pluginData->identifier = [[NSString alloc] initWithBytes:info->PluginUniqueID length:4 encoding:NSASCIIStringEncoding];
        _pluginData->type = info->PluginType;
        
        // Get extended info, and fill out our attributes dictionary.
        NSString *name;
        if(info->PluginName)
            name = [[[NSString alloc] initWithBytes:info->PluginName length:16 encoding:NSASCIIStringEncoding] autorelease];
        else
            name = [self identifier];

        result = _pluginData->main(FF_GETEXTENDEDINFO, 0, 0);
        PluginExtendedInfoStruct *extendedInfo = (PluginExtendedInfoStruct *)result.svalue;
        if (extendedInfo != NULL) {
            NSNumber *version = [NSNumber numberWithFloat:extendedInfo->PluginMajorVersion + (extendedInfo->PluginMinorVersion * 0.001)];
            
            NSString *description;
            if (extendedInfo->Description)
                description = [NSString stringWithCString:extendedInfo->Description encoding:NSASCIIStringEncoding];
            else
                description = @"";
            
            NSString *author;
            if (extendedInfo->About)
                author = [NSString stringWithCString:extendedInfo->About encoding:NSASCIIStringEncoding];
            else
                author = @"";
            
            _pluginData->attributes = [[NSDictionary alloc] initWithObjectsAndKeys:name, VVFFGLPluginAttributeNameKey, version, VVFFGLPluginAttributeVersionKey,
                                       description, VVFFGLPluginAttributeDescriptionKey, author, VVFFGLPluginAttributeAuthorKey,
                                       path, VVFFGLPluginAttributePathKey, nil];
        } else {
            _pluginData->attributes = [[NSDictionary alloc] initWithObjectsAndKeys:name, VVFFGLPluginAttributeNameKey, path, VVFFGLPluginAttributePathKey, nil];
        }
        
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
        NSDictionary *pAttributes;
        NSString *pName;
        BOOL recognized;
        result = _pluginData->main(FF_GETPLUGINCAPS, FF_CAP_MINIMUMINPUTFRAMES, 0);
        for (i = 0; i < result.ivalue; i++) {
            pName = [NSString stringWithFormat:@"Input Image #%u", i];
            pAttributes = [NSDictionary dictionaryWithObjectsAndKeys:VVFFGLParameterTypeImage, VVFFGLParameterAttributeTypeKey,
                          pName, VVFFGLParameterAttributeNameKey, [NSNumber numberWithBool:YES], VVFFGLParameterAttributeRequiredKey, nil];
            [(NSMutableDictionary *)_pluginData->parameters setObject:pAttributes forKey:pName];
        }
        result = _pluginData->main(FF_GETPLUGINCAPS, FF_CAP_MAXIMUMINPUTFRAMES, 0);
        for (; i < result.ivalue; i++) {
            pName = [NSString stringWithFormat:@"Input Image #%u", i];
            pAttributes = [NSDictionary dictionaryWithObjectsAndKeys:VVFFGLParameterTypeImage, VVFFGLParameterAttributeTypeKey,
                          pName, VVFFGLParameterAttributeNameKey, [NSNumber numberWithBool:NO], VVFFGLParameterAttributeRequiredKey, nil];
            [(NSMutableDictionary *)_pluginData->parameters setObject:pAttributes forKey:pName];
        }
        DWORD paramCount = _pluginData->main(FF_GETNUMPARAMETERS, 0, 0).ivalue;
        
        for (i = 0; i < paramCount; i++) {
            pAttributes = [NSMutableDictionary dictionaryWithCapacity:4];
            result = _pluginData->main(FF_GETPARAMETERTYPE, i, 0);
            recognized = YES;
            switch (result.ivalue) {
                case FF_TYPE_BOOLEAN:
                    [pAttributes setValue:VVFFGLParameterTypeBoolean forKey:VVFFGLParameterAttributeTypeKey];
                    result = _pluginData->main(FF_GETPARAMETERDEFAULT, i, 0);
                    [pAttributes setValue:[NSNumber numberWithBool:(result.ivalue ? YES : NO)] forKey:VVFFGLParameterAttributeDefaultValueKey];
                    break;
                case FF_TYPE_EVENT:
                    [pAttributes setValue:VVFFGLParameterTypeEvent forKey:VVFFGLParameterAttributeTypeKey];
                    result = _pluginData->main(FF_GETPARAMETERDEFAULT, i, 0);
                    break;
                case FF_TYPE_RED: // TODO: we may want to synthesize color inputs if we can reliably detect sets of RGBA inputs...
                case FF_TYPE_GREEN:
                case FF_TYPE_BLUE:
                case 11: // The standard defins an alpha value at 11, but it doesn't appear in the headers. Added it to my list of things to mention to FF folk...
                case FF_TYPE_STANDARD:
                case FF_TYPE_XPOS: // TODO: we may want to synthesize point inputs if we can reliably detect sets of X/YPOS inputs...
                case FF_TYPE_YPOS:
                    [pAttributes setValue:VVFFGLParameterTypeNumber forKey:VVFFGLParameterAttributeTypeKey];
                    [pAttributes setValue:[NSNumber numberWithFloat:0.0] forKey:VVFFGLParameterAttributeMinimumValueKey];
                    [pAttributes setValue:[NSNumber numberWithFloat:1.0] forKey:VVFFGLParameterAttributeMaximumValueKey];
                    result = _pluginData->main(FF_GETPARAMETERDEFAULT, i, 0);
                    [pAttributes setValue:[NSNumber numberWithFloat:result.fvalue] forKey:VVFFGLParameterAttributeDefaultValueKey];
                    break;
                case FF_TYPE_TEXT:
                    [pAttributes setValue:VVFFGLParameterTypeString forKey:VVFFGLParameterAttributeTypeKey];
                    result = _pluginData->main(FF_GETPARAMETERDEFAULT, i, 0);
                    if (result.svalue != NULL) {
                        [pAttributes setValue:[NSString stringWithCString:result.svalue encoding:NSASCIIStringEncoding]
                                      forKey:VVFFGLParameterAttributeDefaultValueKey];
                    }
                    break;
                default:
                    recognized = NO;
                    break;
            }
            if (recognized == YES) {
                result = _pluginData->main(FF_GETPARAMETERNAME, i, 0);
                if (result.svalue != NULL) {
                    [pAttributes setValue:[[[NSString alloc] initWithBytes:result.svalue length:16 encoding:NSASCIIStringEncoding] autorelease]
                                  forKey:VVFFGLParameterAttributeNameKey];
                } else {
                    [pAttributes setValue:@"Untitled Parameter" forKey:VVFFGLParameterAttributeNameKey];
                }
                [(NSMutableDictionary *)_pluginData->parameters setObject:pAttributes forKey:[NSString stringWithFormat:@"non-image-parameter-%u", i]];
            }
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
        [_pluginData->attributes release];
        [_pluginData->identifier release];
        free(_pluginData);
    }
    [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (VVFFGLPluginType)type
{
    return _pluginData->type;
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
    return _pluginData->identifier;
}

- (NSDictionary *)attributes
{
    return _pluginData->attributes;
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
