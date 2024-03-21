## Mapping

classify image features and create image objects

*Imalys* provides three mapping alternatives. The option *pixel* will perform a fully self adjusting classification based on pixel features. *Zones* will do the same with zones including the option to use geometric features of the zones for landscape description. *Fabric* combines existing zones to “objects” of several zones. Objects are defined by the spatial combination of their zones. In each case only the source image and number of desired classes must be passed. 

The *pixels* option classifies the spectral properties of the passed image. The process depends on the Euclidean distance of the pixel features in the n-dimensional feature space. As all bands are treated as equal important, the value distribution should be similar. For images calibrated to reflection ([import](3_Import.md)) this is the case. Other bands like elevation or humidity will not fit. The option *equalize* can be used to scale all bands to the same value range.

The *zones* option uses a similar process but with zones instead of pixels. Spectral classification with zones instead of pixels are superior in most cases because zones follow natural boundaries and generalize pixel values. The typical “pepper and salt” effect of pixel orientated classes will not appear. Small differences will be less probably over … by statistical effects. Mapping of zones can include size and shape of he zones. As the values of these features differ largely from reflection the values must be scaled in accordance to the expected results.

The *fabric* option uses existing zones to find and characterize spatial patterns (objects) among them (Appendix E: Background). The spatial distribution of zones and their features over the whole image is analyzed and most common patterns are extracted as object classes. This includes the typical neighborhood of zones. Many real objects are characterized more by their internal structure and their environment but by their spectral composition. Objects are mostly larger than zones. The object definition does not restrict the size of objects but even single zones like waterbodies can be defined as object.

------

### Select

**Mark an image or zones to be classified**

`select = image_filename`

To classify *pixel* or *zones* a source image must be passed. The *fabric* process depends completely on the files stored at the working directory. In this case *select* is not necessary. If multiple images should be classified together, they must be stacked beforehand using the →compile command.

------

### Equalize

**Normalize all values to the same range**

`equalize = true`

If image features with very different value ranges are to be classified, the value ranges should be harmonized. The *equalize* option scales all features to the same value distribution. The  new distribution will be the mean value ±3 standard deviations.

------

### Pixels

**Classifies spectral combinations**

`model = pixels`

The *pixels* option selects a pixel-oriented classification of the given image data. The process uses all bands of the provided image. The process is controlled only by the number of classes in the result. All bands should have a comparable value range as calibrated images do.

------

### Zones

**Classifies all attributes of the given zones**

`model = zones`

The command uses all attributes of the given *zones* for the classification process. Pixel features are ignored. If spectral attributes are mixed with form and size attributes the *equalize* process should be used. *Zones* needs the result of a [features](8_Features.md) command (*index.bit* at the working directory). 

------

### Fabric

**creates and classifies image objects**

`model = zones`

In this context adjacent zones with a specific combination of features are called “objects”. The *fabric* process defines such objects and assigns an ID to each object class. The result is a single layer with class IDs. *Fabric* needs the result of a [features](8_Features.md) command (*index.bit* at the working directory). 

------

### Double

**Defines a large environment for the *fabric* process**

`double = true`

Fabric can use a large environment to define image object properties but the option will need excessive computation time. The use of this option depends on the specific situation.

------

### Classes

**Specifies the number of classes or objects to be created**

`classes = number of classes`

The number of classes should not be too large. Overclassification reduces the accuracy. We recommend to use two classes per desired land use feature. *Imalys* classifies statistically. Coincidence can confuse a statistical analysis. Sometimes one class more or less can (!) significantly improve the quality.

------

### Samples

**Specifies the number of samples to train the classifier**

`samples = number of samples`

To find clusters in the feature space *mapping* uses samples from the image data. They are selected from the image at random places. Samples make the classification much faster than when each pixel or zone has to be evaluated individually. We recommend to use around 1000 samples per desired class.

------

### Values

**Show classification result with “natural” colors**

`values = true`

The primary classification result is a raster layer with class IDs as values and random colors given as a color palette. The *values* option will transfer the random colors to “natural” colors derived from the class definition. The default are the first three bands of the classified image.

------

### Entropy

**Add a class dependent diversity**

`execute = entropy`

The process *entropy* needs a classification to run. If a classification is stored at the working directory or a new classification is called together with *entriopy* the process returns Rao’s entropy based on classes. A sample radius must be given together with the process name.
This process is deprecated. We recommend to use Rao’s diversity based on zones (see [Kernel](6_Kernel.md): Entropy).

​	![image-20240320124820839](/home/c7sepe2/ESIS/GitHub_Commands/4_Compile.md)	d: spectral distance between classes; p: class frequency; k,i: different classes

------

### Radius

**Select the kernel size for the *entropy* extension**

`radius = number`	(kernel radius in pixels)

The kernel radius is defined as the number of pixels between the center and the border of the kernel. The radius “1” produces a 3x3 pixels kernel. Zero is not accepted.
input value

### Example

```
IMALYS [mapping]
…
mapping
	select=index
	model=zones
	classes=30
	samples=30000
```

The classification of pixels, zones and patterns with the *fabric* option differ considerably in their internal processes. Most convenient will be the classification of zones based on a feature table stored at the working directory as shown in this example. *Index* and *zones* select the zones geometry and features to be classified. In our experience 30 different classes are a good starting point to specify about 15 land uses in a natural landscape. 

-----

[Previous](8_Features.md)	–	[Index](Index.md)	–	[Next](10_Compare.md)