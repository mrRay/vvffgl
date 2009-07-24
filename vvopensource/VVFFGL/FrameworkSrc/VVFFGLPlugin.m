//
//  vvFFGLPlugin.m
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import "VVFFGLPlugin.h"
#import "FreeFrame.h"

struct VVFFGLPluginData {
    CFBundleRef bundle;
    FF_Main_FuncPtr main;
    Boolean initted;
    PluginInfoStruct *info;
    PluginExtendedInfoStruct *extendedInfo;
};

NSString * const VVFFGLPluginAttributesNameKey = @"VVFFGLPluginAttributesNameKey";
NSString * const VVFFGLPluginAttributesVersionKey = @"VVFFGLPluginAttributesVersionKey";
NSString * const VVFFGLPluginAttributesDescriptionKey = @"VVFFGLPluginAttributesDescriptionKey";
NSString * const VVFFGLPluginAttributesAuthorKey = @"VVFFGLPluginAttributesAuthorKey";

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
        _pluginData->initted = false;
        
        NSURL *url = [NSURL URLWithString:path];
        if (url == nil) {
            [self release];
            return nil;
        }
        
        _pluginData->bundle = CFBundleCreate(kCFAllocatorDefault, (CFURLRef)url);
        if (_pluginData->bundle == NULL) {
            [self release];
            return nil;
        }
        
        _pluginData->main = CFBundleGetFunctionPointerForName(_pluginData->bundle, CFSTR("plugMain"));
        if (_pluginData->main == NULL) {
            [self release];
            return nil;
        }

        plugMainUnion result;
        result = _pluginData->main(FF_GETINFO, 0, 0);
        if ((result.ivalue != FF_SUCCESS) || (result.svalue == NULL)) {
            [self release];
            return nil;
        }
        _pluginData->info = (PluginInfoStruct *)result.svalue;
        if ((_pluginData->info->PluginType != FF_SOURCE) && (_pluginData->info->PluginType != FF_EFFECT)) {
            // Bail if this is some future other type of plugin.
            [self release];
            return nil;
        }
        
        result = _pluginData->main(FF_GETEXTENDEDINFO, 0, 0);
        if ((result.ivalue != FF_SUCCESS) || (result.svalue == NULL)) {
            // Bail, but do we have to? Could be a bit more elegant dealing with this, which isn't a catastrophic problem.
            [self release];
            return nil;
        }
        _pluginData->extendedInfo = (PluginExtendedInfoStruct *)result.svalue;
        
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
        free(_pluginData);
    }
    [super dealloc];
}

- (VVFFGLPluginType)type
{
    return _pluginData->info->PluginType;
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

@end
