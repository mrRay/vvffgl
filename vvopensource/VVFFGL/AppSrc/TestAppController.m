//
//  FFGLTestAppController.m
//  VVOpenSource
//
//  Created by vade on 10/4/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "TestAppController.h"

#if __BIG_ENDIAN__
#define kFFPixelFormat FFGLPluginBufferPixelFormatRGBA8888
#else
#define kFFPixelFormat FFGLPluginBufferPixelFormatBGRA8888
#endif

#define kRenderBounds NSMakeRect(0, 0, 640, 480)
@implementation TestAppController

- (void)awakeFromNib
{
    [_sourcesTableView setTarget:self];
    [_sourcesTableView setDoubleAction:@selector(addRendererFromTableView:)];
    [_effectsTableView setTarget:self];
    [_effectsTableView setDoubleAction:@selector(addRendererFromTableView:)];
// Coming:
//    _chain = [[RenderChain alloc] initWithOpenGLContext:[_view openGLContext] pixelFormat:kPixelFormat forBounds:kBounds];
//    [_view setRenderChain:self.renderChain];
}

- (void) applicationDidFinishLaunching:(NSNotification *)notification
{
	NSLog(@"FFGL Test App launched");
    /*
     yo
     I ditched your code here and just used an NSOpenGLView, so we don't have to set up the context, etc in code. That OK?
     I've also made the view our own subclass which isn't going to do much, but makes the code clearer I hope.
     
     */
        ffglRenderTimer = [NSTimer timerWithTimeInterval:(1.0/60.0) target:self selector:@selector(renderForTimer:) userInfo:nil repeats:YES];
	[ffglRenderTimer retain];
	[[NSRunLoop currentRunLoop] addTimer:ffglRenderTimer forMode:NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:ffglRenderTimer forMode:NSModalPanelRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:ffglRenderTimer forMode:NSEventTrackingRunLoopMode];

	// for shits and giggles lets make sure we have some plugins in our plugin manager
    // No need to do this - they're loaded because the source/effects panel is bound to the plugin manager in the xib. No code, magic.
//	NSLog(@"Loaded source plugins: %@, loaded effect plugins: %@", [ffglManager sourcePlugins], [ffglManager effectPlugins]);

}

- (void)renderForTimer:(NSTimer *)timer
{
//	NSLog(@"render callback");
}

- (IBAction)addRendererFromTableView:(NSTableView *)sender
{
    NSInteger selectedRow = [sender selectedRow];
    NSArray *sourceArray = (sender == _sourcesTableView ? [[FFGLPluginManager sharedManager] sourcePlugins] : [[FFGLPluginManager sharedManager] effectPlugins]);
    if ((selectedRow >= 0) && (selectedRow < [sourceArray count])) {
        FFGLPlugin *plugin = [sourceArray objectAtIndex:selectedRow];
        NSLog(@"Adding renderer for plugin: %@", (NSString *)[[plugin attributes] objectForKey:FFGLPluginAttributeNameKey]);
        FFGLRenderer *renderer;
        if ([plugin mode] == FFGLPluginModeCPU) {
            renderer = [[[FFGLRenderer alloc] initWithPlugin:plugin pixelFormat:kFFPixelFormat forBounds:kRenderBounds] autorelease];
        } else {
            renderer = [[[FFGLRenderer alloc] initWithPlugin:plugin context:[ffglRenderContext CGLContextObj] forBounds:kRenderBounds] autorelease];
        }
        if ([plugin type] == FFGLPluginTypeSource) {
//            [self.renderChain setSource:renderer]; // Coming.
        } else {
//            [self.renderChain insertObject:renderer inEffectsAtIndex:[[_chain effects] count]]; // Coming.
        }
    }
}
@end
