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

typedef struct FFGLPluginData {
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
}FFGLPluginData;

#define ffglPPrivate(x) ((FFGLPluginData *)_pluginPrivate)->x

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

__attribute__((destructor))
static void finalizer()
{
	if (_FFGLPluginInstances != nil)
	{
		CFRelease(_FFGLPluginInstances);
		_FFGLPluginInstances = nil; // just in case this is called twice
		// _FFGLPluginInstances will only be non-nil if this lock was succesfully created,
		// so no need for any other check.
		pthread_mutex_destroy(&_FFGLPluginInstancesLock);
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
        _pluginPrivate = malloc(sizeof(struct FFGLPluginData));
        if (_pluginPrivate == NULL) {
            pthread_mutex_unlock(&_FFGLPluginInstancesLock);
            [self release];
            return nil;
        }
        // Set everything we need in dealloc, in case we bail from init.
        ffglPPrivate(initted) = NO;
        ffglPPrivate(handle) = NULL;
        ffglPPrivate(bufferPixelFormats) = nil;
        ffglPPrivate(parameters) = nil;
        ffglPPrivate(attributes) = nil;
		ffglPPrivate(sortedParameterKeys) = nil;
		ffglPPrivate(main) = NULL;
        
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
				ffglPPrivate(handle) = dlopen(cPathToLoadable, (RTLD_NOW | RTLD_LOCAL | RTLD_FIRST));
				if (ffglPPrivate(handle) != NULL) {
					ffglPPrivate(main) = dlsym(ffglPPrivate(handle), "plugMain");
				}
			}
		}
		if (ffglPPrivate(main) == NULL)
		{
			pthread_mutex_unlock(&_FFGLPluginInstancesLock);
			[self release];
			return nil;
		}
        
        FFMixed result;
		
        // Initialise the plugin. According to the FF spec we only need to do this before calling instantiate,
        // but some plugins require it before other calls, so it should be our first call.
        result = ffglPPrivate(main)(FF_INITIALISE, (FFMixed)0U, 0);
        if (result.UIntValue != FF_SUCCESS) {
            pthread_mutex_unlock(&_FFGLPluginInstancesLock);
            [self release];
            return nil;
        }
        ffglPPrivate(initted) = YES;
        
        // Get basic plugin info, and check we are a type (source or effect) we know about.
        result = ffglPPrivate(main)(FF_GETINFO, (FFMixed)0U, 0);
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
        ffglPPrivate(type) = info->PluginType;
        
        ffglPPrivate(attributes) = [[NSMutableDictionary alloc] initWithCapacity:6];
        // Get our identifier to store in the attributes dictionary.
        NSString *identifier = [NSString stringWithFFPluginDubiousBytes:info->PluginUniqueID nominalLength:4];
        if (identifier != nil)
            [(NSMutableDictionary *)ffglPPrivate(attributes) setObject:identifier forKey:FFGLPluginAttributeIdentifierKey];
        
        // Get extended info, and fill out our attributes dictionary.
        NSString *name;
        if(info->PluginName) {
            name = [NSString stringWithFFPluginDubiousBytes:info->PluginName nominalLength:16];
            name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        } else {
            name = identifier;
        }
        if (name != nil)
            [(NSMutableDictionary *)ffglPPrivate(attributes) setObject:name forKey:FFGLPluginAttributeNameKey];
        
        [(NSMutableDictionary *)ffglPPrivate(attributes) setObject:[[path copy] autorelease] forKey:FFGLPluginAttributePathKey];
		
        result = ffglPPrivate(main)(FF_GETEXTENDEDINFO, (FFMixed)0U, 0);
        FFPluginExtendedInfoStruct *extendedInfo = (FFPluginExtendedInfoStruct *)result.PointerValue;
        if (extendedInfo != NULL) {
            NSNumber *version = [NSNumber numberWithFloat:extendedInfo->PluginMajorVersion + (extendedInfo->PluginMinorVersion * 0.001)];
            [(NSMutableDictionary *)ffglPPrivate(attributes) setObject:version forKey:FFGLPluginAttributeVersionKey];
            
            NSString *description;
            if (extendedInfo->Description) {
                description = [NSString stringWithCString:extendedInfo->Description encoding:NSASCIIStringEncoding];
                [(NSMutableDictionary *)ffglPPrivate(attributes) setObject:description forKey:FFGLPluginAttributeDescriptionKey];
            }            
			
            NSString *author;
            if (extendedInfo->About) {
                author = [NSString stringWithCString:extendedInfo->About encoding:NSASCIIStringEncoding];
                [(NSMutableDictionary *)ffglPPrivate(attributes) setObject:author forKey:FFGLPluginAttributeAuthorKey];
            }
        }
        
        // Determine our mode.
        result = ffglPPrivate(main)(FF_GETPLUGINCAPS, (FFMixed)FF_CAP_PROCESSOPENGL, 0);
        if (result.UIntValue == FF_SUPPORTED) {
            ffglPPrivate(mode) = FFGLPluginModeGPU;
            // We (by conversion) support all pixel-formats
            ffglPPrivate(bufferPixelFormats) = [[NSArray arrayWithObjects:FFGLPixelFormatARGB8888, FFGLPixelFormatBGRA8888,
												FFGLPixelFormatRGB888, FFGLPixelFormatBGR888,
												FFGLPixelFormatRGB565, FFGLPixelFormatBGR565, nil] retain];
        } else {
            ffglPPrivate(mode) = FFGLPluginModeCPU;
            // Fill out our preferred mode
            ffglPPrivate(preferredBufferMode) = ffglPPrivate(main)(FF_GETPLUGINCAPS, (FFMixed)FF_CAP_COPYORINPLACE, 0).UIntValue;
            /*
             Get information about the pixel formats we support. FF plugins only support native-endian pixel formats.
             */
            ffglPPrivate(bufferPixelFormats) = [[NSMutableArray alloc] initWithCapacity:3];
            result = ffglPPrivate(main)(FF_GETPLUGINCAPS, (FFMixed)FF_CAP_16BITVIDEO, 0);
            if (result.UIntValue == FF_SUPPORTED) {
#if __BIG_ENDIAN__
                [(NSMutableArray *)ffglPPrivate(bufferPixelFormats) addObject:FFGLPixelFormatRGB565];
#else
                [(NSMutableArray *)ffglPPrivate(bufferPixelFormats) addObject:FFGLPixelFormatBGR565];
#endif
            }
            result = ffglPPrivate(main)(FF_GETPLUGINCAPS, (FFMixed)FF_CAP_24BITVIDEO, 0);
            if (result.UIntValue == FF_SUPPORTED) {
#if __BIG_ENDIAN__
                [(NSMutableArray *)ffglPPrivate(bufferPixelFormats) addObject:FFGLPixelFormatRGB888];
#else
                [(NSMutableArray *)ffglPPrivate(bufferPixelFormats) addObject:FFGLPixelFormatBGR888];
#endif
            }
            result = ffglPPrivate(main)(FF_GETPLUGINCAPS, (FFMixed)FF_CAP_32BITVIDEO, 0);
            if (result.UIntValue == FF_SUPPORTED) {
#if __BIG_ENDIAN__
                [(NSMutableArray *)ffglPPrivate(bufferPixelFormats) addObject:FFGLPixelFormatARGB8888];
#else
                [(NSMutableArray *)ffglPPrivate(bufferPixelFormats) addObject:FFGLPixelFormatBGRA8888];
#endif
            }            
        }
        
        // See if we support setTime
        ffglPPrivate(supportsSetTime) = ffglPPrivate(main)(FF_GETPLUGINCAPS, (FFMixed)FF_CAP_SETTIME, 0).UIntValue;
        
        // Discover our parameters, which include the plugin's parameters plus video inputs.
        ffglPPrivate(parameters) = [[NSMutableDictionary alloc] initWithCapacity:4];
		ffglPPrivate(sortedParameterKeys) = [[NSMutableArray alloc] initWithCapacity:4];
        uint32_t i = 0;
        NSDictionary *pAttributes;
        NSString *pName;
        BOOL recognized;
        // Image inputs as parameters
        result = ffglPPrivate(main)(FF_GETPLUGINCAPS, (FFMixed)FF_CAP_MINIMUMINPUTFRAMES, 0);
        ffglPPrivate(minFrames) = result.UIntValue;
        result = ffglPPrivate(main)(FF_GETPLUGINCAPS, (FFMixed)FF_CAP_MAXIMUMINPUTFRAMES, 0);
        ffglPPrivate(maxFrames) = result.UIntValue;
        for (i = 0; i < ffglPPrivate(minFrames); i++) {
            pName = [NSString stringWithFormat:@"%@ %u", FFGLLocalized(@"Image"), i+1];
            pAttributes = [NSDictionary dictionaryWithObjectsAndKeys:FFGLParameterTypeImage, FFGLParameterAttributeTypeKey,
                           pName, FFGLParameterAttributeNameKey, [NSNumber numberWithBool:YES], FFGLParameterAttributeRequiredKey, 
                           [NSNumber numberWithUnsignedInt:i], FFGLParameterAttributeIndexKey, nil];
            [(NSMutableDictionary *)ffglPPrivate(parameters) setObject:pAttributes forKey:pName];
			[(NSMutableArray *)ffglPPrivate(sortedParameterKeys) addObject:pName];
        }
        for (; i < ffglPPrivate(maxFrames); i++) {
            pName = [NSString stringWithFormat:@"%@ %u", FFGLLocalized(@"Image"), i+1];
            pAttributes = [NSDictionary dictionaryWithObjectsAndKeys:FFGLParameterTypeImage, FFGLParameterAttributeTypeKey,
                           pName, FFGLParameterAttributeNameKey, [NSNumber numberWithBool:NO], FFGLParameterAttributeRequiredKey,
                           [NSNumber numberWithUnsignedInt:i], FFGLParameterAttributeIndexKey, nil];
            [(NSMutableDictionary *)ffglPPrivate(parameters) setObject:pAttributes forKey:pName];
			[(NSMutableArray *)ffglPPrivate(sortedParameterKeys) addObject:pName];
        }        
        // Non-image parameters
		
        uint32_t paramCount = ffglPPrivate(main)(FF_GETNUMPARAMETERS, (FFMixed)0U, 0).UIntValue;
        for (i = 0; i < paramCount; i++) {
            pAttributes = [NSMutableDictionary dictionaryWithCapacity:4];
            result = ffglPPrivate(main)(FF_GETPARAMETERTYPE, (FFMixed)i, 0);
            recognized = YES;
            switch (result.UIntValue) {
                case FF_TYPE_BOOLEAN:
                    [pAttributes setValue:FFGLParameterTypeBoolean forKey:FFGLParameterAttributeTypeKey];
                    result = ffglPPrivate(main)(FF_GETPARAMETERDEFAULT, (FFMixed)i, 0);
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
                    result = ffglPPrivate(main)(FF_GETPARAMETERDEFAULT, (FFMixed)i, 0);
					[pAttributes setValue:[NSNumber numberWithFloat:*((float *)&result.UIntValue)] forKey:FFGLParameterAttributeDefaultValueKey];
                    break;
                case FF_TYPE_TEXT:
                    [pAttributes setValue:FFGLParameterTypeString forKey:FFGLParameterAttributeTypeKey];
                    result = ffglPPrivate(main)(FF_GETPARAMETERDEFAULT, (FFMixed)i, 0);
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
                result = ffglPPrivate(main)(FF_GETPARAMETERNAME, (FFMixed)i, 0);
                if (result.PointerValue != NULL) {
                    [pAttributes setValue:[NSString stringWithFFPluginDubiousBytes:result.PointerValue nominalLength:16]
                                   forKey:FFGLParameterAttributeNameKey];
                } else {
                    [pAttributes setValue:FFGLLocalized(@"Untitled Parameter") forKey:FFGLParameterAttributeNameKey];
                }
                [pAttributes setValue:[NSNumber numberWithBool:YES] forKey:FFGLParameterAttributeRequiredKey];
                [pAttributes setValue:[NSNumber numberWithUnsignedInt:i] forKey:FFGLParameterAttributeIndexKey];
				NSString *parameterKey = [NSString stringWithFormat:@"non-image-parameter-%u", i];
                [(NSMutableDictionary *)ffglPPrivate(parameters) setObject:pAttributes forKey:parameterKey];
				[(NSMutableArray *)ffglPPrivate(sortedParameterKeys) addObject:parameterKey];
            }
        }
        
        [_FFGLPluginInstances setObject:self forKey:path];
        pthread_mutex_unlock(&_FFGLPluginInstancesLock);
    }
    return self;
}

- (void)unregisterAndRelease
{
    if (_pluginPrivate != NULL) {
        pthread_mutex_lock(&_FFGLPluginInstancesLock);
        NSString *path = [ffglPPrivate(attributes) objectForKey:FFGLPluginAttributePathKey];
        if (path != nil) {
            [_FFGLPluginInstances removeObjectForKey:path];
        }
        pthread_mutex_unlock(&_FFGLPluginInstancesLock); 
        if (ffglPPrivate(initted) == YES) {
            ffglPPrivate(main)(FF_DEINITIALISE, (FFMixed)0U, 0);
        }
		if (ffglPPrivate(handle) != NULL)
			dlclose(ffglPPrivate(handle));
        [ffglPPrivate(bufferPixelFormats) release];
        [ffglPPrivate(parameters) release];
        [ffglPPrivate(attributes) release];
		[ffglPPrivate(sortedParameterKeys) release];
        free(_pluginPrivate);
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
    return [[ffglPPrivate(attributes) objectForKey:FFGLPluginAttributePathKey] hash];
}

- (FFGLPluginType)type
{
    return ffglPPrivate(type);
}

- (FFGLPluginMode)mode
{
    return ffglPPrivate(mode);
}

- (NSArray *)supportedBufferPixelFormats
{
    return ffglPPrivate(bufferPixelFormats);
}

- (NSDictionary *)attributes
{
    return ffglPPrivate(attributes);
}

- (NSArray *)parameterKeys
{
    return ffglPPrivate(sortedParameterKeys);
}

- (NSDictionary *)attributesForParameterWithKey:(NSString *)key
{
    return [ffglPPrivate(parameters) objectForKey:key];
}

#pragma mark Plugin Private for Renderers

- (NSUInteger)_minimumInputFrameCount
{
    return ffglPPrivate(minFrames);
}

- (NSUInteger)_maximumInputFrameCount
{
    return ffglPPrivate(maxFrames);
}

- (BOOL)_supportsSetTime
{
    return ffglPPrivate(supportsSetTime);
}

- (BOOL)_prefersFrameCopy
{
    return (ffglPPrivate(preferredBufferMode) == FF_CAP_PREFER_COPY) || (ffglPPrivate(preferredBufferMode) == FF_CAP_PREFER_BOTH) ? YES : NO;
}

#pragma mark Instances

- (FFGLPluginInstance)_newInstanceWithSize:(NSSize)size pixelFormat:(NSString *)format
{
    if (ffglPPrivate(mode) == FFGLPluginModeGPU) {
        FFGLViewportStruct viewport = {0, 0, size.width, size.height};
        return ffglPPrivate(main)(FF_INSTANTIATEGL, (FFMixed)(void *)&viewport, 0).PointerValue;
    } else if (ffglPPrivate(mode) == FFGLPluginModeCPU) {
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
		FFGLPluginInstance instance = ffglPPrivate(main)(FF_INSTANTIATE, (FFMixed)(void *)&videoInfo, 0).PointerValue;
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
    if (ffglPPrivate(mode) == FFGLPluginModeGPU)
		ffglPPrivate(main)(FF_DEINSTANTIATEGL, (FFMixed)0U, instance).UIntValue;
    else if (ffglPPrivate(mode) == FFGLPluginModeCPU)
        ffglPPrivate(main)(FF_DEINSTANTIATE, (FFMixed)0U, instance).UIntValue;
}

- (id)_valueForNonImageParameterKey:(NSString *)key ofInstance:(FFGLPluginInstance)instance
{
    NSDictionary *pattributes = [self attributesForParameterWithKey:key];
    if (pattributes == nil) {
        [NSException raise:@"FFGLPluginException" format:@"No such key: %@", key];
        return nil;        
    }
    uint32_t pindex = [[pattributes objectForKey:FFGLParameterAttributeIndexKey] unsignedIntValue];
    FFMixed result = ffglPPrivate(main)(FF_GETPARAMETER, (FFMixed)pindex, instance);
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
    ffglPPrivate(main)(FF_SETPARAMETER, (FFMixed)(void *)&param, instance);
}

- (void)_setValue:(NSNumber *)value forNumberParameterAtIndex:(NSUInteger)index ofInstance:(FFGLPluginInstance)instance
{
    FFSetParameterStruct param;
    param.ParameterNumber = index;
	float f = [value floatValue];
	f = fminf(1.0, fmaxf(0.0, f));
	param.NewParameterValue = (FFMixed)(uint32_t)*((uint32_t *)&f);
    ffglPPrivate(main)(FF_SETPARAMETER, (FFMixed)(void *)&param, instance);    
}

- (void)_setTime:(NSTimeInterval)time ofInstance:(FFGLPluginInstance)instance
{
    ffglPPrivate(main)(FF_SETTIME, (FFMixed)(void *)&time, instance);
}

- (BOOL)_imageInputAtIndex:(uint32_t)index willBeUsedByInstance:(FFGLPluginInstance)instance
{
    return ffglPPrivate(main)(FF_GETINPUTSTATUS, (FFMixed)index, instance).UIntValue;
}

- (BOOL)_processFrameCopy:(FFGLProcessFrameCopyStruct *)frameInfo forInstance:(FFGLPluginInstance)instance
{
    FFMixed result = ffglPPrivate(main)(FF_PROCESSFRAMECOPY, (FFMixed)(void *)frameInfo, instance);
    return result.UIntValue == FF_SUCCESS ? YES : NO;
}

- (BOOL)_processFrameInPlace:(void *)buffer forInstance:(FFGLPluginInstance)instance
{
    FFMixed result = ffglPPrivate(main)(FF_PROCESSFRAME, (FFMixed)buffer, instance);
    return result.UIntValue == FF_SUCCESS ? YES : NO;
}

- (BOOL)_processFrameGL:(FFGLProcessGLStruct *)frameInfo forInstance:(FFGLPluginInstance)instance
{
    FFMixed result = ffglPPrivate(main)(FF_PROCESSOPENGL, (FFMixed)(void *)frameInfo, instance);
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
