//
//  VVFFGLPluginManager.m
//  VVOpenSource
//
//  Created by Tom on 23/07/2009.
//  Copyright 2009 Tom Butterworth. All rights reserved.
//

#import "VVFFGLPluginManager.h"
#import "VVFFGLPlugin.h"

static VVFFGLPluginManager *_sharedPluginManager = nil;

@implementation VVFFGLPluginManager
#pragma mark Singleton Instance
+ (VVFFGLPluginManager*)sharedManager
{
    @synchronized(self) {
        if (_sharedPluginManager == nil) {
            [[self alloc] init]; // assignment not done here but in alloc
        }
    }
    return _sharedPluginManager;
}

+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (_sharedPluginManager == nil) {
            _sharedPluginManager = [super allocWithZone:zone];
            return _sharedPluginManager;  // assignment and return on first allocation
        }
    }
    return nil; //on subsequent allocation attempts return nil
}


- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain
{
    return self;
}

- (unsigned)retainCount
{
    return UINT_MAX;  //denotes an object that cannot be released
}

- (void)release
{
    //do nothing
}

- (id)autorelease
{
    return self;
}

- (id)init
{
    if (self = [super init]) {
        _sources = [[NSMutableArray alloc] initWithCapacity:4];
        _effects = [[NSMutableArray alloc] initWithCapacity:4];
    }
    return self;
}
#pragma mark Plugin Management
- (void)loadLibraryPlugins
{
    
}

- (void)loadPluginsFromDirectories:(NSArray *)paths
{
    for (NSString *path in paths) {
        [self loadPluginsFromDirectory:path];
    }
}

- (void)loadPluginsFromDirectory:(NSString *)path
{
    @synchronized(self) {
        NSArray *contents;
        NSString *file, *path;
        VVFFGLPlugin *plugin;
        contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
        for (file in contents) {
            if([[file pathExtension] isEqualToString:@"frf"]) {
                plugin = [[VVFFGLPlugin alloc] initWithPath:file];
                [plugin autorelease];
                // TODO: check type, add to apt array
            }
        }        
    }
    
}
- (NSArray *)plugins
{
    NSArray *combined;
    @synchronized(self) {
        combined = [_sources arrayByAddingObjectsFromArray:_effects];        
    }
    return combined;
}
- (NSArray *)sourcePlugins
{
    NSArray *copy;
    @synchronized(self) {
        copy = [[_sources copy] autorelease];
    }
    return copy;
}
- (NSArray *)effectPlugins
{
    NSArray *copy;
    @synchronized(self) {
        copy = [[_effects copy] autorelease];
    }
    return copy;
}
@end
