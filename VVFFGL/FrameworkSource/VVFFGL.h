
#import "FFGLPluginManager.h"
#import "FFGLPlugin.h"
#import "FFGLRenderer.h"
#import "FFGLImage.h"






/*!
\mainpage

\htmlonly

<style type="text/css">
big	{
	font-size: 14pt;
	text-align: left;
}
p	{
	font-size:10pt;
}
li	{
	font-size: 10pt;
	text-indent: 25pt;
}
</style>

<big>What is VVFFGL?</big>
<p>
VVFFGL is a framework that provides a simple, organized objective-c interface for working with FreeFrame and FreeFrame GL plugins.  Emphasis has been placed on ease of use and efficiency.  The interface is similar to working with quartz composer's "QCRenderer" class.
</p>

<big>How do i use VVFFGL in my Mac application?</big>
<p>
The general idea is to compile the framework/frameworks you want to use, add them to your XCode project so you may link against them, and then set up a build phase to copy the framework into your application bundle.  This is fairly important: most of the time when you link against a framework, the framework is expected to be installed on your (or your user's) OS.  VVFFGL is different: your application will include a compiled copy of it, so you're guaranteed that the framework won't change outside of your control (which means you won't inherit bugs or have to deal with changed APIs until you're ready to do so).  Here's the exact procedure:

<li>Open the VVFFGL project in XCode</li>
<li>In XCode, make the framework your active target.  Make sure the build mode is set to "Release"!</li>
<li>Build the target.  Your compiled framework can be found in "./build/Release/".  You may now close the VVFFGL project you opened in XCode.</li>
<li>Open your application's project file in XCode, and drag the compiled framework into your XCode project so you can link against it.</li>
<li>From XCode's "Project" menu, add a new "Copy Files" build phase to your application/target.</li>
<li>Change the destination of the "Copy Files" build phase you just created so the files are being copied into the 'Frameworks' folder within your app bundle.</li>
<li>Expand your application/target, and drag the VVFFGL framework you just added to your project into the copy files build phase you created in the last step.  Be sure to drag the framework *from your project* into the copy files build phase- you're not dragging from the Finder to XCode, you should be dragging from XCode to XCode!</li>
<li>Double-click your application/target in the left-hand list of your project window (or select it and get its info).  Click on the "Build" tab, locate the "Runpath Search Paths" setting, and add the following paths: "@loader_path/../Frameworks" and "@executable_path/../Frameworks".</li>
<li>That's it- you're done now.  You can import/include objects from the framework in your source just as you normally would via #import VVFFGL/VVFFGL.h!</li>
</p>

<big>How do i use VVFFGL in my plugin?</big>
<p>
If you're writing a plugin, you need to weak-link against these frameworks. If you don't do this and the host app which loads your plugin has a different version of this framework installed, you won't know which version of the framework will get used- which usually means a crash and/or generally confusing and buggy behavior. You can prevent this by weak-linking against the framework: your plugin will still contain its own copy of the framework, but if the host app has already loaded a different version of the framework that will be used instead.

<li>Follow the steps listed above for using this framework in a Mac application- you're going to be embedding a copy of these frameworks in your plugin just as you would for a mac app.</li>
<li>Double-click your plugin/target in the left-hand list of your project window (or select it and get its info). Click on the "Build" tab, locate the "Other Linker Flags" setting, and add the following flag: "-weak_framework VVFFGL"</li>
</p>

<big>What's the general workflow for working with VVFFGL?</big>
<p>
<li>Typically, you'll want to start off by using FFGLPluginManager to get a list of the FF filters installed on your system.</li>
<li>Once you have a list of the available plugins, at some point you'll want to create one.  This is done by instantiating FFGLPlugin.  An FFGLPlugin instance corresponds to a loaded (instantiated) instance of the FF or FFGL plugin you want to work with.  The FFGLPlugin class basically exists to load the raw data and as a placeholder that describes the properties of the plugin- FFGLPlugin does not do any rendering.</li>
<li>Once you have an FFGLPlugin instance, create an FFGLRenderer instance with it using an OpenGL context.  FFGLRenderer is how you pass data to- or retrieve data from- the FF/FFGL plugin you've created.  FFGLRenderer is also the class that does all the rendering, and outputs FFGLImage instances (which you can use in your app).</li>
</p>




\endhtmlonly
*/
