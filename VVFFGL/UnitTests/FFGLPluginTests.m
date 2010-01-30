//
//  FFGLPluginTests.m
//  VVFFGL
//
//  Created by Tom on 30/01/2010.
//  Copyright 2010 Tom Butterworth. All rights reserved.
//

#import "FFGLPluginTests.h"


@implementation FFGLPluginTests
- (void)testReusingInstances
{
	FFGLPlugin *plugin = [[[FFGLPluginManager sharedManager] plugins] lastObject];
	NSString *path = [[plugin attributes] objectForKey:FFGLPluginAttributePathKey];
	FFGLPlugin *duplicate = [[[FFGLPlugin alloc] initWithPath:path] autorelease];
	STAssertTrue(plugin == duplicate, @"FFGLPlugin returned a new instance when it should have re-used one.");
}

- (void)testReleasingPlugins
{
	// Because the FFGLPlugin class keeps track of instances so it can return a duplicate we check
	// it is still releasing them when it should
	
	// Create an autorelease pool so we can force the release of our plugin
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	FFGLPlugin *plugin = [[[FFGLPluginManager sharedManager] plugins] lastObject];
	NSString *path = [[[plugin attributes] objectForKey:FFGLPluginAttributePathKey] retain];
	[[FFGLPluginManager sharedManager] unloadPlugin:plugin];
	[pool drain];
	// allocate something else so we are unlikely to get the same address in memory back
	NSObject *padding = [[NSObject alloc] init];
	FFGLPlugin *duplicate = [[[FFGLPlugin alloc] initWithPath:path] autorelease];
	[padding release];
	[path release];
	STAssertTrue(plugin != duplicate, @"FFGLPlugin (probably) didn't release a plugin when it should have.");
}
@end
