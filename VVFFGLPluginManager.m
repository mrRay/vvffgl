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
    for (path in paths) {
        [self loadPluginsFromDirectory:path];
    }
}

- (void)loadPluginsFromDirectory:(NSString *)path
{
    @synchronized(self) {
        NSArray *contents;
        NSMutableArray *fileTypeHandlers;
        NSString *file, *path, *extension;
        NSBundle *bundle;
        contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL];
        for (file in contents) {
            if([[file pathExtension] isEqualToString:@"frf"]) {
                bundle = [NSBundle bundleWithPath:[path stringByAppendingPathComponent:file]];
                bundleClass = [bundle principalClass]; // loads the bundle code
                if ([bundleClass conformsToProtocol:@protocol(v002Plugin)]) {
                    [_plugins addObject:v002IdentifierFromClass(bundleClass)];
                    capabilities = [bundleClass capabilities];
                    if ((capabilities & kv002PluginCapabilities_OpensFilePath) || (capabilities & kv002PluginCapabilities_OpensFilePathList)) {
                        for (extension in [bundleClass loadableFileTypes]) {
                            if (fileTypeHandlers = [_fileHandlers objectForKey:extension]) {
                                [fileTypeHandlers addObject:v002IdentifierFromClass(bundleClass)];
                            } else {
                                [_fileHandlers setObject:[NSMutableArray arrayWithObject:v002IdentifierFromClass(bundleClass)] forKey:extension];
                            }
                        }
                    }
                    [self.delegate pluginLoaded:v002IdentifierFromClass(bundleClass)]; 
                } else {
                    // Plugin doesn't conform to protocol.
                    [bundle unload];
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
