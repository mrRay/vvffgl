//
//  FFGLTestAppController.m
//  VVOpenSource
//
//  Created by vade on 10/4/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "TestAppController.h"

#if __BIG_ENDIAN__
#define kFFPixelFormat FFGLPixelFormatRGBA8888
#else
#define kFFPixelFormat FFGLPixelFormatBGRA8888
#endif

#define kRenderBounds NSMakeRect(0, 0, 640, 480)

@implementation TestAppController

- (void)awakeFromNib
{
    [_sourcesTableView setTarget:self];
    [_sourcesTableView setDoubleAction:@selector(addRendererFromTableView:)];
    [_effectsTableView setTarget:self];
    [_effectsTableView setDoubleAction:@selector(addRendererFromTableView:)];
    [self willChangeValueForKey:@"renderChain"];
    _chain = [[RenderChain alloc] initWithOpenGLContext:[_renderView openGLContext] pixelFormat:kFFPixelFormat forBounds:kRenderBounds];
    [self didChangeValueForKey:@"renderChain"];
    [_renderView setRenderChain:_chain];
    if ([[[FFGLPluginManager sharedManager] sourcePlugins] count] == 0) {
        NSLog(@"No source plugins loaded. Copy some to your \"~/Library/Graphics/Free Frame Plug-Ins\" folder.");
    }
    if ([[[FFGLPluginManager sharedManager] effectPlugins] count] == 0) {
        NSLog(@"No effect plugins loaded. Copy some to your \"~/Library/Graphics/Free Frame Plug-Ins\" folder.");
    }
    [_paramsView bind:@"renderer" toObject:_renderChainRenderersController withKeyPath:@"selection.self" options:nil];
}

- (void)dealloc
{
    [_chain release];
    [super dealloc];
}

- (void) applicationDidFinishLaunching:(NSNotification *)notification
{
	NSLog(@"FFGL Test App launched");
    /*
     yo
     I ditched your code here and just used an NSOpenGLView, so we don't have to set up the context, etc in code. That OK?
     I've also made the view our own subclass which isn't going to do much, but makes the code clearer I hope.
     
     */
        _renderStart = [NSDate timeIntervalSinceReferenceDate];
        ffglRenderTimer = [NSTimer timerWithTimeInterval:(1.0/60.0) target:self selector:@selector(renderForTimer:) userInfo:nil repeats:YES];
	[ffglRenderTimer retain];
	[[NSRunLoop currentRunLoop] addTimer:ffglRenderTimer forMode:NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:ffglRenderTimer forMode:NSModalPanelRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:ffglRenderTimer forMode:NSEventTrackingRunLoopMode];

	// for shits and giggles lets make sure we have some plugins in our plugin manager
    // No need to do this - they're loaded because the source/effects panel is bound to the plugin manager in the xib. No code, magic.
//	NSLog(@"Loaded source plugins: %@, loaded effect plugins: %@", [ffglManager sourcePlugins], [ffglManager effectPlugins]);

}

@synthesize FPS = _fps;

- (RenderChain *)renderChain
{
    return _chain;
}

- (void)renderForTimer:(NSTimer *)timer
{
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    [_chain renderAtTime:now - _renderStart];
    NSTimeInterval fpsTime = now - _fpsStart;
    _frameCount++;
    if (fpsTime > 0.5) {
        double fps;
        if (_frameCount > 5)
            fps = _frameCount * 2;
        else
            fps = _frameCount / fpsTime;
        _frameCount = 0;
        _fpsStart = now;            
        [self setFPS:fps];
    }
    [_renderView setNeedsDisplay:YES];
}

- (IBAction)addRendererFromTableView:(NSTableView *)sender
{
    NSInteger selectedRow = [sender selectedRow];
    NSArray *sourceArray = (sender == _sourcesTableView ? [[FFGLPluginManager sharedManager] sourcePlugins] : [[FFGLPluginManager sharedManager] effectPlugins]);
    if ((selectedRow >= 0) && (selectedRow < [sourceArray count])) {
        FFGLPlugin *plugin = [sourceArray objectAtIndex:selectedRow];
        NSLog(@"Adding renderer for %@ plugin: \"%@\"", [plugin mode] == FFGLPluginModeCPU ? @"CPU" : @"GPU", (NSString *)[[plugin attributes] objectForKey:FFGLPluginAttributeNameKey]);
        FFGLRenderer *renderer = nil;
        if ([plugin mode] == FFGLPluginModeCPU) {
            if ([[plugin supportedBufferPixelFormats] containsObject:kFFPixelFormat]) {
                renderer = [[[FFGLRenderer alloc] initWithPlugin:plugin context:[[_renderView openGLContext] CGLContextObj] pixelFormat:kFFPixelFormat forBounds:kRenderBounds] autorelease];
            }
        } else {
            renderer = [[[FFGLRenderer alloc] initWithPlugin:plugin context:[[_renderView openGLContext] CGLContextObj] pixelFormat:kFFPixelFormat forBounds:kRenderBounds] autorelease];
        }
        if (renderer == nil) {
            NSLog(@"Couldn't create plugin renderer.");
        } else {
            if ([plugin type] == FFGLPluginTypeSource) {
                [_chain setSource:renderer];
            } else {
                [_chain insertObject:renderer inEffectsAtIndex:[[_chain effects] count]];
            }
        }
    }
}
@end
