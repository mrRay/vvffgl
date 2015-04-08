# Introduction #
FreeFrame is an open-source image effect plugin system.  FreeFrame 1.5 (also known as FreeFrame GL, or just FFGL) is a hardware-accelerated version of this plugin system that tries to do video processing on the GPU.  This framework provides a simple, fast, version-agnostic objective-c interface for working with FF and FFGL plugins; the goal of this framework is to simplify the process of adding FF/FFGL support to cocoa apps.  This framework is basically done- it's being used in a commercial application with great results and no complaints, and has been since early 2011.

# I'm not a programmer, I just want the FF/FFGL QC plugin! #
Please check the "downloads" section.

# How to get help #
Please open a new issue.  If we're totally swamped it may take a bit for us to get back to you.

# Documentation #
VVFFGL is commented liberally, and also uses Doxygen to to assemble a high-level set of documentation to get you started, which you can find here:

http://www.vidvox.net/rays_oddsnends/vvffgl_doc/index.html

# What does this project do/include/make? #
  * VVFFGL.xcodeproj builds the VVFFGL framework.  This framework is necessary if you want to build any of the other targets in this class.
  * VVFFGL.xcodeproj also builds an FF/FFGL test application.  This is a very bare-bones application, and it only works if you have FF/FFGL plugins installed on your system.
  * FFGLQC.xcodeproj builds a Quartz Composer plugin (FFGLQC.plugin) that lets you load and work with FF/FFGL plugins inside Quartz Composer.

# Hey, where'd all this great stuff come from? #
VVFFGL was written by Tom Butterworth (bangnoise) and Anton Marini (vade), and commissioned by Vidvox.  Enjoy!