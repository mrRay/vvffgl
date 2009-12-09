//
//  FFGLPlugin.m
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//

#import "FFGLPlugin.h"
#import "FFGLInternal.h"
#import "FFGLFreeFrame.h"

#import <pthread.h>
#import <dlfcn.h>

/*
 
 LOCKING
    Currently no locking occurs around calls to plugins, except that which occurs in FFGLRenderer.
    This means plugins instances are accessed serially, but plugMain is assumed to be thread-safe.
    Discussion on the FF list suggests this might work, but we should
        a) discuss with the list if this is an acceptable policy
        b) request that a future FF standard makes explicit the locking requirements of plugins and clients
        c) experiment like crazy, see if we can crash some plugins doing it this way
 */

struct FFGLPluginData {
    void *handle;
    FF_Main_FuncPtr main;
    BOOL initted;
    FFGLPluginType type;
    FFGLPluginMode mode;
    NSUInteger minFrames;
    NSUInteger maxFrames;
    NSUInteger preferredBufferMode;
    BOOL supportsSetTime;
    NSArray *bufferPixelFormats;
    NSDictionary *parameters;
	NSArray *sortedParameterKeys;
    NSDictionary *attributes;
};

@interface NSString (FFGLPluginExtensions)
/*
 Lots of FF plugins return null-terminated strings when the spec requires strings of a specific length.
 Use this method to get strings from the plugin in situations where the spec requires them to be a
 specific length.
 */
+ (NSString *)stringWithFFPluginDubiousBytes:(const void *)bytes nominalLength:(NSUInteger)len;
@end

NSString * const FFGLPixelFormatARGB8888 = @"FFGLPixelFormatARGB8888";
NSString * const FFGLPixelFormatBGRA8888 = @"FFGLPixelFormatBGRA8888";
NSString * const FFGLPixelFormatRGB888 = @"FFGLPixelFormatRGB888";
NSString * const FFGLPixelFormatBGR888 = @"FFGLPixelFormatBGR888";
NSString * const FFGLPixelFormatRGB565 = @"FFGLPixelFormatRGB565";
NSString * const FFGLPixelFormatBGR565 = @"FFGLPixelFormatBGR565";

NSString * const FFGLPluginAttributeNameKey = @"FFGLPluginAttributeNameKey";
NSString * const FFGLPluginAttributeVersionKey = @"FFGLPluginAttributeVersionKey";
NSString * const FFGLPluginAttributeDescriptionKey = @"FFGLPluginAttributeDescriptionKey";
NSString * const FFGLPluginAttributeIdentifierKey = @"FFGLPluginAttributeIdentifierKey";
NSString * const FFGLPluginAttributeAuthorKey = @"FFGLPluginAttributeAuthorKey";
NSString * const FFGLPluginAttributePathKey = @"FFGLPluginAttributePathKey";

NSString * const FFGLParameterAttributeTypeKey = @"FFGLParameterAttributeTypeKey";
NSString * const FFGLParameterAttributeNameKey = @"FFGLParameterAttributeNameKey";
NSString * const FFGLParameterAttributeDefaultValueKey = @"FFGLParameterAttributeDefaultValueKey";
NSString * const FFGLParameterAttributeMinimumValueKey = @"FFGLParameterAttributeMinimumValueKey";
NSString * const FFGLParameterAttributeMaximumValueKey = @"FFGLParameterAttributeMaximumValueKey";
NSString * const FFGLParameterAttributeRequiredKey = @"FFGLParameterAttributeRequiredKey";
NSString * const FFGLParameterAttributeIndexKey = @"FFGLParameterAttributeIndexKey"; // Private

NSString * const FFGLParameterTypeBoolean = @"FFGLParameterTypeBoolean";
NSString * const FFGLParameterTypeEvent = @"FFGLParameterTypeEvent";
NSString * const FFGLParameterTypeNumber = @"FFGLParameterTypeNumber";
NSString * const FFGLParameterTypeString = @"FFGLParameterTypeString";
NSString * const FFGLParameterTypeImage = @"FFGLParameterTypeImage";

static NSMutableDictionary *_FFGLPluginInstances = nil;
static pthread_mutex_t  _FFGLPluginInstancesLock;

@implementation FFGLPlugin

+ (void)initialize
{
    /*
     We keep track of all instances using a dictionary, returning an existing instance for a path passed in at init if one exists.
     Our dictionary doesn't retain its contents, so FFGLPlugins can still be released.
     */
    if (self == [FFGLPlugin class]) { // so we only do this once (not for a subclass)
        if (pthread_mutex_init(&_FFGLPluginInstancesLock, NULL) == 0) {
            _FFGLPluginInstances = (NSMutableDictionary *)CFDictionaryCreateMutable(kCFAllocatorDefault, 10, &kCFTypeDictionaryKeyCallBacks, NULL);
        }
    }
}

- (id)init
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithPath:(NSString *)path
{
    if (self = [super init]) {
	if (path == nil) {
            [self release];
            return nil;
        }
        pthread_mutex_lock(&_FFGLPluginInstancesLock);
	// check if we already have an instance of this plugin
	FFGLPlugin *p;
        p = [_FFGLPluginInstances objectForKey:path];
        if (p != nil) {
            pthread_mutex_unlock(&_FFGLPluginInstancesLock);
            [self release];
            return [p retain];
        }
        _pluginData = malloc(sizeof(struct FFGLPluginData));
        if (_pluginData == NULL) {
            pthread_mutex_unlock(&_FFGLPluginInstancesLock);
            [self release];
            return nil;
        }
        // Set everything we need in dealloc, in case we bail from init.
        _pluginData->initted = NO;
        _pluginData->handle = NULL;
        _pluginData->bufferPixelFormats = nil;
        _pluginData->parameters = nil;
        _pluginData->attributes = nil;
		_pluginData->sortedParameterKeys = nil;
	_pluginData->main = NULL;
        
	NSString *loadableName = [[path lastPathComponent] stringByDeletingPathExtension];
	CFStringRef pathToLoadable = (CFStringRef)[NSString stringWithFormat:@"%@/Contents/MacOS/%@", path, loadableName];
	if (pathToLoadable != NULL)
	{
	    CFIndex buffSize = CFStringGetMaximumSizeOfFileSystemRepresentation(pathToLoadable);
	    char cPathToLoadable[buffSize];
	    if (CFStringGetFileSystemRepresentation(pathToLoadable, cPathToLoadable, buffSize))
	    {
		/*
		 Don't change (RTLD_NOW | RTLD_LOCAL | RTLD_FIRST) -
		 Changes can have a serious impact on speed (ie increase init time by a factor of 3).
		 */
		_pluginData->handle = dlopen(cPathToLoadable, (RTLD_NOW | RTLD_LOCAL | RTLD_FIRST));
		if (_pluginData->handle != NULL) {
		    _pluginData->main = dlsym(_pluginData->handle, "plugMain");
		}
	    }
	}
	if (_pluginData->main == NULL)
	{
	    pthread_mutex_unlock(&_FFGLPluginInstancesLock);
	    [self release];
	    return nil;
	}
        
        FFMixed result;

        // Initialise the plugin. According to the FF spec we only need to do this before calling instantiate,
        // but some plugins require it before other calls, so it should be our first call.
        result = _pluginData->main(FF_INITIALISE, (FFMixed)0U, 0);
        if (result.UIntValue != FF_SUCCESS) {
            pthread_mutex_unlock(&_FFGLPluginInstancesLock);
            [self release];
            return nil;
        }
        _pluginData->initted = YES;
        
        // Get basic plugin info, and check we are a type (source or effect) we know about.
        result = _pluginData->main(FF_GETINFO, (FFMixed)0U, 0);
        FFPluginInfoStruct *info = (FFPluginInfoStruct *)result.PointerValue;
		if (info == NULL) {
            pthread_mutex_unlock(&_FFGLPluginInstancesLock);
            [self release];
            return nil;
        }
        if ((info->PluginType != FF_PLUGIN_SOURCE) && (info->PluginType != FF_PLUGIN_EFFECT)) {
            // Bail if this is some future other type of plugin.
            pthread_mutex_unlock(&_FFGLPluginInstancesLock);
            [self release];
            return nil;
        }
        
        /*
         Long init
            Current strategy is to do all our parameter/attributes calls to the plugin at init, so we can give that information out without locks
            because we won't be changing anything in memory after init... Can change if it proves problematic, in which case the below will move
            to respective methods.
         */
        
        // Set type from the PluginInfoStruct.
        _pluginData->type = info->PluginType;
        
        _pluginData->attributes = [[NSMutableDictionary alloc] initWithCapacity:6];
        // Get our identifier to store in the attributes dictionary.
        NSString *identifier = [NSString stringWithFFPluginDubiousBytes:info->PluginUniqueID nominalLength:4];
        if (identifier != nil)
            [(NSMutableDictionary *)_pluginData->attributes setObject:identifier forKey:FFGLPluginAttributeIdentifierKey];
        
        // Get extended info, and fill out our attributes dictionary.
        NSString *name;
        if(info->PluginName) {
            name = [NSString stringWithFFPluginDubiousBytes:info->PluginName nominalLength:16];
            name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        } else {
            name = identifier;
        }
        if (name != nil)
            [(NSMutableDictionary *)_pluginData->attributes setObject:name forKey:FFGLPluginAttributeNameKey];
        
        [(NSMutableDictionary *)_pluginData->attributes setObject:[[path copy] autorelease] forKey:FFGLPluginAttributePathKey];

        result = _pluginData->main(FF_GETEXTENDEDINFO, (FFMixed)0U, 0);
        FFPluginExtendedInfoStruct *extendedInfo = (FFPluginExtendedInfoStruct *)result.PointerValue;
        if (extendedInfo != NULL) {
            NSNumber *version = [NSNumber numberWithFloat:extendedInfo->PluginMajorVersion + (extendedInfo->PluginMinorVersion * 0.001)];
            [(NSMutableDictionary *)_pluginData->attributes setObject:version forKey:FFGLPluginAttributeVersionKey];
            
            NSString *description;
            if (extendedInfo->Description) {
                description = [NSString stringWithCString:extendedInfo->Description encoding:NSASCIIStringEncoding];
                [(NSMutableDictionary *)_pluginData->attributes setObject:description forKey:FFGLPluginAttributeDescriptionKey];
            }            
    
            NSString *author;
            if (extendedInfo->About) {
                author = [NSString stringWithCString:extendedInfo->About encoding:NSASCIIStringEncoding];
                [(NSMutableDictionary *)_pluginData->attributes setObject:author forKey:FFGLPluginAttributeAuthorKey];
            }
        }
        
        // Determine our mode.
        result = _pluginData->main(FF_GETPLUGINCAPS, (FFMixed)FF_CAP_PROCESSOPENGL, 0);
        if (result.UIntValue == FF_SUPPORTED) {
            _pluginData->mode = FFGLPluginModeGPU;
            // We don't support any pixel formats.
            _pluginData->bufferPixelFormats = [[NSArray alloc] init];
        } else {
            _pluginData->mode = FFGLPluginModeCPU;
            // Fill out our preferred mode
            _pluginData->preferredBufferMode = _pluginData->main(FF_GETPLUGINCAPS, (FFMixed)FF_CAP_COPYORINPLACE, 0).UIntValue;
            /*
             Get information about the pixel formats we support. FF plugins only support native-endian pixel formats.
             */
            _pluginData->bufferPixelFormats = [[NSMutableArray alloc] initWithCapacity:3];
            result = _pluginData->main(FF_GETPLUGINCAPS, (FFMixed)FF_CAP_16BITVIDEO, 0);
            if (result.UIntValue == FF_SUPPORTED) {
#if __BIG_ENDIAN__
                [(NSMutableArray *)_pluginData->bufferPixelFormats addObject:FFGLPixelFormatRGB565];
#else
                [(NSMutableArray *)_pluginData->bufferPixelFormats addObject:FFGLPixelFormatBGR565];
#endif
            }
            result = _pluginData->main(FF_GETPLUGINCAPS, (FFMixed)FF_CAP_24BITVIDEO, 0);
            if (result.UIntValue == FF_SUPPORTED) {
#if __BIG_ENDIAN__
                [(NSMutableArray *)_pluginData->bufferPixelFormats addObject:FFGLPixelFormatRGB888];
#else
                [(NSMutableArray *)_pluginData->bufferPixelFormats addObject:FFGLPixelFormatBGR888];
#endif
            }
            result = _pluginData->main(FF_GETPLUGINCAPS, (FFMixed)FF_CAP_32BITVIDEO, 0);
            if (result.UIntValue == FF_SUPPORTED) {
#if __BIG_ENDIAN__
                [(NSMutableArray *)_pluginData->bufferPixelFormats addObject:FFGLPixelFormatARGB8888];
#else
                [(NSMutableArray *)_pluginData->bufferPixelFormats addObject:FFGLPixelFormatBGRA8888];
#endif
            }            
        }
        
        // See if we support setTime
        _pluginData->supportsSetTime = _pluginData->main(FF_GETPLUGINCAPS, (FFMixed)FF_CAP_SETTIME, 0).UIntValue;
        
        // Discover our parameters, which include the plugin's parameters plus video inputs.
        _pluginData->parameters = [[NSMutableDictionary alloc] initWithCapacity:4];
		_pluginData->sortedParameterKeys = [[NSMutableArray alloc] initWithCapacity:4];
        uint32_t i = 0;
        NSDictionary *pAttributes;
        NSString *pName;
        BOOL recognized;
        // Image inputs as parameters
        result = _pluginData->main(FF_GETPLUGINCAPS, (FFMixed)FF_CAP_MINIMUMINPUTFRAMES, 0);
        _pluginData->minFrames = result.UIntValue;
        result = _pluginData->main(FF_GETPLUGINCAPS, (FFMixed)FF_CAP_MAXIMUMINPUTFRAMES, 0);
        _pluginData->maxFrames = result.UIntValue;
        for (i = 0; i < _pluginData->minFrames; i++) {
            pName = [NSString stringWithFormat:@"Image %u", i+1];
            pAttributes = [NSDictionary dictionaryWithObjectsAndKeys:FFGLParameterTypeImage, FFGLParameterAttributeTypeKey,
                           pName, FFGLParameterAttributeNameKey, [NSNumber numberWithBool:YES], FFGLParameterAttributeRequiredKey, 
                           [NSNumber numberWithUnsignedInt:i], FFGLParameterAttributeIndexKey, nil];
            [(NSMutableDictionary *)_pluginData->parameters setObject:pAttributes forKey:pName];
			[(NSMutableArray *)_pluginData->sortedParameterKeys addObject:pName];
        }
        for (; i < _pluginData->maxFrames; i++) {
            pName = [NSString stringWithFormat:@"Image %u", i+1];
            pAttributes = [NSDictionary dictionaryWithObjectsAndKeys:FFGLParameterTypeImage, FFGLParameterAttributeTypeKey,
                           pName, FFGLParameterAttributeNameKey, [NSNumber numberWithBool:NO], FFGLParameterAttributeRequiredKey,
                           [NSNumber numberWithUnsignedInt:i], FFGLParameterAttributeIndexKey, nil];
            [(NSMutableDictionary *)_pluginData->parameters setObject:pAttributes forKey:pName];
			[(NSMutableArray *)_pluginData->sortedParameterKeys addObject:pName];
        }        
        // Non-image parameters
	
        uint32_t paramCount = _pluginData->main(FF_GETNUMPARAMETERS, (FFMixed)0U, 0).UIntValue;
        for (i = 0; i < paramCount; i++) {
            pAttributes = [NSMutableDictionary dictionaryWithCapacity:4];
            result = _pluginData->main(FF_GETPARAMETERTYPE, (FFMixed)i, 0);
            recognized = YES;
            switch (result.UIntValue) {
                case FF_TYPE_BOOLEAN:
                    [pAttributes setValue:FFGLParameterTypeBoolean forKey:FFGLParameterAttributeTypeKey];
                    result = _pluginData->main(FF_GETPARAMETERDEFAULT, (FFMixed)i, 0);
                    [pAttributes setValue:[NSNumber numberWithBool:(result.UIntValue ? YES : NO)] forKey:FFGLParameterAttributeDefaultValueKey];
                    break;
                case FF_TYPE_EVENT:
                    [pAttributes setValue:FFGLParameterTypeEvent forKey:FFGLParameterAttributeTypeKey];
                    break;
                case FF_TYPE_RED: // TODO: we may want to synthesize color inputs if we can reliably detect sets of RGBA inputs...
                case FF_TYPE_GREEN:
                case FF_TYPE_BLUE:
                case 11: // The standard defins an alpha value at 11, but it doesn't appear in the headers. Added it to my list of things to mention to FF folk...
                case FF_TYPE_STANDARD:
                case FF_TYPE_XPOS: // TODO: we may want to synthesize point inputs if we can reliably detect sets of X/YPOS inputs...
                case FF_TYPE_YPOS:
                    [pAttributes setValue:FFGLParameterTypeNumber forKey:FFGLParameterAttributeTypeKey];
                    [pAttributes setValue:[NSNumber numberWithFloat:0.0] forKey:FFGLParameterAttributeMinimumValueKey];
                    [pAttributes setValue:[NSNumber numberWithFloat:1.0] forKey:FFGLParameterAttributeMaximumValueKey];
                    result = _pluginData->main(FF_GETPARAMETERDEFAULT, (FFMixed)i, 0);
					[pAttributes setValue:[NSNumber numberWithFloat:*((float *)&result.UIntValue)] forKey:FFGLParameterAttributeDefaultValueKey];
                    break;
                case FF_TYPE_TEXT:
                    [pAttributes setValue:FFGLParameterTypeString forKey:FFGLParameterAttributeTypeKey];
                    result = _pluginData->main(FF_GETPARAMETERDEFAULT, (FFMixed)i, 0);
                    if (result.PointerValue != NULL) {
                        [pAttributes setValue:[NSString stringWithCString:result.PointerValue encoding:NSASCIIStringEncoding]
                                      forKey:FFGLParameterAttributeDefaultValueKey];
                    }
                    break;
                default:
                    /*
                     We ignore parameters we don't recognize. Instead we could bail on init, or assume them to be number parameters.
                     */
                    recognized = NO;
                    break;
            }
            if (recognized == YES) {
                result = _pluginData->main(FF_GETPARAMETERNAME, (FFMixed)i, 0);
                if (result.PointerValue != NULL) {
                    [pAttributes setValue:[NSString stringWithFFPluginDubiousBytes:result.PointerValue nominalLength:16]
                                   forKey:FFGLParameterAttributeNameKey];
                } else {
                    [pAttributes setValue:@"Untitled Parameter" forKey:FFGLParameterAttributeNameKey];
                }
                [pAttributes setValue:[NSNumber numberWithBool:YES] forKey:FFGLParameterAttributeRequiredKey];
                [pAttributes setValue:[NSNumber numberWithUnsignedInt:i] forKey:FFGLParameterAttributeIndexKey];
				NSString *parameterKey = [NSString stringWithFormat:@"non-image-parameter-%u", i];
                [(NSMutableDictionary *)_pluginData->parameters setObject:pAttributes forKey:parameterKey];
				[(NSMutableArray *)_pluginData->sortedParameterKeys addObject:parameterKey];
            }
        }
        
        [_FFGLPluginInstances setObject:self forKey:path];
        pthread_mutex_unlock(&_FFGLPluginInstancesLock);
    }
    return self;
}

- (void)unregisterAndRelease
{
    if (_pluginData != NULL) {
        pthread_mutex_lock(&_FFGLPluginInstancesLock);
        NSString *path = [_pluginData->attributes objectForKey:FFGLPluginAttributePathKey];
        if (path != nil) {
            [_FFGLPluginInstances removeObjectForKey:path];
        }
        pthread_mutex_unlock(&_FFGLPluginInstancesLock); 
        if (_pluginData->initted == YES) {
            _pluginData->main(FF_DEINITIALISE, (FFMixed)0U, 0);
        }
	if (_pluginData->handle != NULL)
	    dlclose(_pluginData->handle);
        [_pluginData->bufferPixelFormats release];
        [_pluginData->parameters release];
        [_pluginData->attributes release];
		[_pluginData->sortedParameterKeys release];
        free(_pluginData);
    }    
}

- (void)dealloc
{   
    [self unregisterAndRelease];
    [super dealloc];
}

- (void)finalize
{
    [self unregisterAndRelease];
    [super finalize];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [self retain];
}

- (BOOL)isEqual:(id)anObject
{
    /* This depends on our instance tracking being functional, otherwise
	we would have to compare our attributes */
    if (anObject == self) {
        return YES;
    }
    return NO;
}

- (NSUInteger)hash
{
    return [[_pluginData->attributes objectForKey:FFGLPluginAttributePathKey] hash];
}

- (FFGLPluginType)type
{
    return _pluginData->type;
}

- (FFGLPluginMode)mode
{
    return _pluginData->mode;
}

- (NSArray *)supportedBufferPixelFormats
{
    return _pluginData->bufferPixelFormats;
}

- (NSDictionary *)attributes
{
    return _pluginData->attributes;
}

- (NSArray *)parameterKeys
{
    return _pluginData->sortedParameterKeys;
}

- (NSDictionary *)attributesForParameterWithKey:(NSString *)key
{
    return [_pluginData->parameters objectForKey:key];
}

#pragma mark Plugin Private for Renderers

- (NSUInteger)_minimumInputFrameCount
{
    return _pluginData->minFrames;
}

- (NSUInteger)_maximumInputFrameCount
{
    return _pluginData->maxFrames;
}

- (BOOL)_supportsSetTime
{
    return _pluginData->supportsSetTime;
}

- (BOOL)_prefersFrameCopy
{
    return (_pluginData->preferredBufferMode == FF_CAP_PREFER_COPY) || (_pluginData->preferredBufferMode == FF_CAP_PREFER_BOTH) ? YES : NO;
}

#pragma mark Instances

- (FFGLPluginInstance)_newInstanceWithSize:(NSSize)size pixelFormat:(NSString *)format
{
    if (_pluginData->mode == FFGLPluginModeGPU) {
        FFGLViewportStruct viewport = {0, 0, size.width, size.height};
        return _pluginData->main(FF_INSTANTIATEGL, (FFMixed)(void *)&viewport, 0).PointerValue;
    } else if (_pluginData->mode == FFGLPluginModeCPU) {
        FFVideoInfoStruct videoInfo;
        if ([format isEqualToString:FFGLPixelFormatBGRA8888] || [format isEqualToString:FFGLPixelFormatARGB8888])
            videoInfo.BitDepth = FF_CAP_32BITVIDEO;
        else if ([format isEqualToString:FFGLPixelFormatBGR888] || [format isEqualToString:FFGLPixelFormatRGB888])
            videoInfo.BitDepth = FF_CAP_24BITVIDEO;
        else if ([format isEqualToString:FFGLPixelFormatBGR565] || [format isEqualToString:FFGLPixelFormatRGB565])
            videoInfo.BitDepth = FF_CAP_16BITVIDEO;
        else {
            [NSException raise:@"FFGLPluginException" format:@"Unrecognized pixelFormat."];
            return 0;
        }
        videoInfo.Orientation = FF_ORIENTATION_TL; // I think ;) If it's upside down then FF_ORIENTATION_BL.
        videoInfo.FrameHeight = size.height;
        videoInfo.FrameWidth = size.width;
		FFGLPluginInstance instance = _pluginData->main(FF_INSTANTIATE, (FFMixed)(void *)&videoInfo, 0).PointerValue;
		if (instance == NULL) {
			NSLog(@"instance zero, if we see this log, we need a rethink");
		}
		return instance;
    } else {
        return 0; // Yikes
    }
}

- (void)_disposeInstance:(FFGLPluginInstance)instance
{
    // Plugins indicate success or failure in return, but as it's not clear what
    // failure means, let's ignore it.
    if (_pluginData->mode == FFGLPluginModeGPU)
		_pluginData->main(FF_DEINSTANTIATEGL, (FFMixed)0U, instance).UIntValue;
    else if (_pluginData->mode == FFGLPluginModeCPU)
        _pluginData->main(FF_DEINSTANTIATE, (FFMixed)0U, instance).UIntValue;
}

- (id)_valueForNonImageParameterKey:(NSString *)key ofInstance:(FFGLPluginInstance)instance
{
    NSDictionary *pattributes = [self attributesForParameterWithKey:key];
    if (pattributes == nil) {
        [NSException raise:@"FFGLPluginException" format:@"No such key: %@", key];
        return nil;        
    }
    uint32_t pindex = [[pattributes objectForKey:FFGLParameterAttributeIndexKey] unsignedIntValue];
    FFMixed result = _pluginData->main(FF_GETPARAMETER, (FFMixed)pindex, instance);
    if ([[pattributes objectForKey:FFGLParameterAttributeTypeKey] isEqualToString:FFGLParameterTypeString]) {
        return [NSString stringWithCString:result.PointerValue encoding:NSASCIIStringEncoding];
    } else {
        return [NSNumber numberWithFloat:*((float *)&result.UIntValue)];
    }
}

- (void)_setValue:(NSString *)value forStringParameterAtIndex:(NSUInteger)index ofInstance:(FFGLPluginInstance)instance
{
    if (value == nil) {
        value = @"";
    }
    FFSetParameterStruct param;
    param.ParameterNumber = index;
    param.NewParameterValue = (FFMixed)(void *)[(NSString *)value cStringUsingEncoding:NSASCIIStringEncoding];
    _pluginData->main(FF_SETPARAMETER, (FFMixed)(void *)&param, instance);
}

- (void)_setValue:(NSNumber *)value forNumberParameterAtIndex:(NSUInteger)index ofInstance:(FFGLPluginInstance)instance
{
    FFSetParameterStruct param;
    param.ParameterNumber = index;
	float f = [(NSNumber *)value floatValue];
	param.NewParameterValue = (FFMixed)(uint32_t)*((uint32_t *)&f);
    _pluginData->main(FF_SETPARAMETER, (FFMixed)(void *)&param, instance);    
}

- (void)_setTime:(NSTimeInterval)time ofInstance:(FFGLPluginInstance)instance
{
    _pluginData->main(FF_SETTIME, (FFMixed)(void *)&time, instance);
}

- (BOOL)_imageInputAtIndex:(uint32_t)index willBeUsedByInstance:(FFGLPluginInstance)instance
{
    return _pluginData->main(FF_GETINPUTSTATUS, (FFMixed)index, instance).UIntValue;
}

- (BOOL)_processFrameCopy:(FFGLProcessFrameCopyStruct *)frameInfo forInstance:(FFGLPluginInstance)instance
{
    FFMixed result = _pluginData->main(FF_PROCESSFRAMECOPY, (FFMixed)(void *)frameInfo, instance);
    return result.UIntValue == FF_SUCCESS ? YES : NO;
}

- (BOOL)_processFrameInPlace:(void *)buffer forInstance:(FFGLPluginInstance)instance
{
    FFMixed result = _pluginData->main(FF_PROCESSFRAME, (FFMixed)buffer, instance);
    return result.UIntValue == FF_SUCCESS ? YES : NO;
}

- (BOOL)_processFrameGL:(FFGLProcessGLStruct *)frameInfo forInstance:(FFGLPluginInstance)instance
{
    FFMixed result = _pluginData->main(FF_PROCESSOPENGL, (FFMixed)(void *)frameInfo, instance);
    return result.UIntValue == FF_SUCCESS ? YES : NO;
}
@end

@implementation NSString (FFGLPluginExtensions)

+ (NSString *)stringWithFFPluginDubiousBytes:(const void *)bytes nominalLength:(NSUInteger)len {
    NSUInteger i;
    NSUInteger safe;
    for (i = safe = 0; i < len; i++) {
        if (((char *)bytes)[i] == 0)
            break;
        safe++;
    }
    return [[[NSString alloc] initWithBytes:bytes length:safe encoding:NSASCIIStringEncoding] autorelease];
}

@end
