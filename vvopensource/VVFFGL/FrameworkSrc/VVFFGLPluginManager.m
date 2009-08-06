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
        _auto = YES;
    }
    return self;
}
#pragma mark Plugin Management

- (BOOL)loadsPluginsAutomatically
{
    BOOL result;
    @synchronized(self) {
        result = _auto;
    }
    return result;
}

- (void)setLoadsPluginsAutomatically:(BOOL)autoLoads
{
    @synchronized(self) {
        _auto = autoLoads;
    }
}

- (void)loadLibraryPlugins
{
    NSArray *libraryDirectories = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask - NSSystemDomainMask, YES);
    NSMutableArray *directories = [NSMutableArray arrayWithCapacity:2];
    NSString *path;
    for (path in libraryDirectories) {
        // TODO: Decide where the common plug-in location should be.
        [directories addObject:[path stringByAppendingPathComponent:@"Graphics/Free Frame Plug-Ins"]];
    }
    @synchronized(self) {
        if (_libraryLoaded == NO) {
            [self loadPluginsFromDirectories:directories];
            _libraryLoaded = YES;
        }
    }

}

- (void)loadApplicationPlugins
{
    @synchronized(self) {
        if (_appLoaded == NO) {
            [self loadPluginsFromDirectory:[[NSBundle mainBundle] builtInPlugInsPath]];
            _appLoaded = YES;
        }
    }
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
        NSString *file;
        VVFFGLPlugin *plugin;
        contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
        for (file in contents) {
            // So far spotted in the wild: .bundle, .frf. If we find others, we could skip this check altogether. .plugin is an Apple-defined extension
            // which gets its own pretty icon and can't be opened as a folder in the Finder, but nobody making FF plugins seems to be using it, but they should!
            if([[file pathExtension] isEqualToString:@"frf"] || [[file pathExtension] isEqualToString:@"bundle"]
               || [[file pathExtension] isEqualToString:@"plugin"]) {
                plugin = [[[VVFFGLPlugin alloc] initWithPath:[path stringByAppendingPathComponent:file]] autorelease];
                if (plugin != nil) {
                    if ([plugin type] == VVFFGLPluginSourceType) {
                        [_sources addObject:plugin];  
                    } else if([plugin type] == VVFFGLPluginEffectType) {
                        [_effects addObject:plugin];
                    }
                }
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
        if (_auto && (_libraryLoaded == NO)) {
            [self loadLibraryPlugins];
            [self loadApplicationPlugins];
        }
        copy = [[_sources copy] autorelease];
    }
    return copy;
}

- (NSArray *)effectPlugins
{
    NSArray *copy;
    @synchronized(self) {
        if (_auto) {
            [self loadLibraryPlugins];
            [self loadApplicationPlugins];
        }
        copy = [[_effects copy] autorelease];
    }
    return copy;
}
@end
