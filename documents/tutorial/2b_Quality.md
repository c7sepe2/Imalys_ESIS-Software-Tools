### T2b	Enhance image quality

A main problem of satellite images are dropouts due to cloud coverage. Less noticeable but of similar importance is the landscape change in time. Each image is a snapshot. Dropouts and changes can be controlled by collecting information of different but similar images. Tutorial 2b shows how to extract a seamless image with typical values out of a couple of patchy images.

*Reduce* with *execute=bestof* uses the median to return the most common value for each pixel in an image stack. The result is a “typical” value for a time period of a few weeks or months. Almost everywhere clouds are random in time. If the majority of single pixels are clean, the most common value is free of clouds and cloud shadows. To get an impression how the process works, compare the imported images from October, September and August (tutorial 2d) with the result of the *bestof* process. 

```
IMALYS [tutorial 2b]
home
	directory=/home/»user«/.imalys
	clear=false
	log=/home/»user«/ESIS/results
compile
	period=20220501-20220731
reduce
	select=compile
	execute=bestof	
export
	select=bestof
	target=/home/»user«/ESIS/results/bestof_summer.tif
```

»user« must be exchanged with the home directory of the user!

-----

Tutorial 2b uses the results of tutorial 2a. The default working directory *»user«/.imalys* is assigned by the *home* command but not cleared to use the imported images for subsequent processes.

The [compile](../manual/4_Compile.md) command stacks all selected images, controls the position of different frames and records the image quality for the different layers. The result name includes sensor and time. The *period* process stacks all bands taken from May to July. *Compile* is mandatory if different images should be compared or processed together.

The [reduce](../manual/5_Reduce.md) command transforms the compiled stack to a new image. *Bestof* reduces a multi image stack to one image with the same bands or colors as one of the original images. The *bestof* process tries to return the most significant content of the different bands. *Bestof* depends on the extended image metadata that [compile](../manual/4_Compile.md) provides. 

The [export] process transfers the image into a Geo-TIFF and stores the result to a freely selected place. The new image format is defined by the extension. No extension will select the ENVI labeled format as it is used at the working directory.

The results of the [compile](../manual/4_Compile.md) and the [reduce](../manual/5_Reduce.md) commands are called without a path name. If no path is given, *Imalys* looks at the working directory.

-----

[Index](Index.md)