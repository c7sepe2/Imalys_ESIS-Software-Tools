## Zones

**Delineate homogeneous image elements**

The *zones* process delineates a seamless network of image segments that completely covers the image. The process tries to minimize the pixel diversity within each zone. Zones were introduced to provide a structural basis for landscape diversity and other structural features. They allow an easy transformation of raster images to a vector format like maps. Zones are stored in an internal format to support rapid processing. Use the [Export](11_Export.md) command to get attributed polygons. 

The process can be controlled by the *size* and the *bonds* parameter. Technically the zones will grow until the diversity within the zones can not be reduced further by combining zones. The resulting zones can be rather large. The *size* parameter will terminate the process when the mean of all zones have reached the input. The *bonds* parameter controls the size differences of the resulting zones. *Low* will allow a wide range of sizes, *high* will force the result to almost equal sizes and *medium* is a compromise between both. *Accurate* only works with classified images and is used to convert classified raster images to a vector format.

*Zones* at an later processing stage are always the combination of smaller *zones*. The number of input layers is not restricted. To control the result of the zone generation an ESRI shape file *index* is created at the working directory. Zones can be classified and combined to larger *objects* (see [Mapping](9_Mapping.md))). 

------

#### Select

**Mark one image as basis of the zones process**

`select = filename`

The zones command will work with classified and scalar images. Scalar images will be segmented in order to minimize the local variance of the pixel values. Classified images (maps) will be converted to a vector format. Each classified area will be translated to one zone.

------

#### size

**Select the mean size of the zones**

`size = number of pixels`

The density of zones is mainly controlled by the *size* parameter. The input is interpreted as mean size of all resulting zones and can be further qualified by the *bonds* option. The *size* of zones is counted in pixels. 

------

### Bonds

**Select low, medium, high or accurate size bounding**

`bonds = low | medium | high | accurate`

The medium size of the zones given by the *size* parameter can be applied rather strictly `[bonds = high]` to return almost equally sized zones, medium strictly or loose `[bonds = low]` for a broad variety of sizes. *accurate* will transfer the boundaries of an classified image unmodified to a vector layer. 

------

### Sieve

**Merge small zones with larger ones**

`sieve = number of internal boundaries`

Very small zones like single pixels or short pixel rows may not be desired. The parameter *sieve* allows to merge small zones with larger ones. The passed number is interpreted as accepted pixel boundaries within the zone. `[sieve = 1]` will erase only single pixels, `[sieve = 2]` will erase pixel pairs and so on. As dot shaped zones show more internal boundaries than a linear arrangement the process prefers narrow shaped zones.

------

### Example

```
IMALYS [zones]
…
zones
	select=compile
	bonds=low
	size=50
```

The zones example uses the result of a [compile](4_Compile.md) process to create new zones. The *bonds* option allows largely different size of the resulting zones and the whole process is terminated by *size* as the mean size of all zones reaches about 50 pixels.

-----

[Previous](6_Kernel.md)	–	[Index](Index.md)	–	[Next](8_Features.md)