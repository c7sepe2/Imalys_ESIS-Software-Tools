## Features

**Create zone attributes from size, shape and pixel statistics**

During [zones](7_Zones.md) creation only the boundaries of the individual areas are recorded. The features command can add attributes to characterize the different spectral and morphological attributes of the zones. Each call of the features command will reset the whole attribute table. All features are stored in an internal format for rapid processing. Use the [export]() command to get attributed polygons.

*Select* will assign spectral features to the zones. Spectral features will always be the mean of all pixels within the border of he zone. The process allows only one input image. Other images must be stacked beforehand and passed as stack. 

*Execute* is used to add a couple of morphological and spectral features. *Execute* can be repeated as often as necessary. 

*Entropy* calculates Rao’s Entropy or ß-Diversity using [zones](7_Zones.md) instead of a kernel. Textural features like *texture* or *normal* return the “roughness” of an image. Regular pattern will show a high roughness but their deviation or spectral diversity might be comparably low. Several proposals (3) (5) to measure diversity share the concept to compare not only adjacent pixels but all of them within a given region. Usually this region is given as a moving window or kernel. Zones provide an alternative that is defined by regional image properties. The *texture* and the *normal* process for zones are also restricted to the boundaries of the zones.

*Dendrites*, *proportion* and *relation* add morphological features of the zones. *Dendrites* looks at single zones, *proportion* compares the size of adjacent zones and *relation* returns the diversity of possible influence of neighbor zones. All of them are designed to be independent of the absolute size of the zones, as the absolute size can be selected freely. As *dendrites* depends on perimeter and size of the zones, the results can not be compared between different images.

*Diversity* mimics the spectral diversity at pixel scale for zones. As zones differ in size, shape and shared edges the diversity is not a simple mean but is calculated from the number of shared edges. For multispectral images the deviation of the different bands is calculated independently and the principal component of all deviations is taken as the final value. 

*Diffusion* emphasizes local maxima and minima of all features. The algorithm mimics diffusion through membranes. During the process, features “migrate” into the neighboring zone like soluble substances and combine with existing concentrations. The intensity of diffusion depends on the length of the common border, the concentration difference and the selected number of iterations. The size of the zones provides the stock of soluble substance.

------

### Delete

**Delete the existing attributes and create a new table**

`Delete = true`

------

### Select

**Assign spectral features as zone attributes**

`select = filename`

The *select* process adds all spectral features of the selected image to the attribute table. The band names are preserved as field names if possible. Each image with the same geometry as the zones image can be selected.

------

### Entropy

**Pixel diversity following Rao’s proposal**

`execute = entropy`

The *entropy* process returns the spectral diversity of all pixels within one zone. For multispectral images the diversity is calculated independently for each band and the first principal component of all diversities is taken as the final result.

​	![image-20240320113611345](/home/c7sepe2/ESIS/GitHub_Commands/8_entropy.png)	dij: Density difference; I,j: neighbor pixels; pi, pj: frequency of pixel values “i” and “j”

------

### Texture

**Pixel texture for individual zones**

`execute = texture`

The *texture* process returns the mean difference between all pixel pairs within an individual zone. The process thus returns the “roughness” of the image. The *normal* process will return a brightness independent result.

​	![image-20240320114020548](/home/c7sepe2/ESIS/GitHub_Commands/8_texture.png)	v: pixel value; i,j: adjacent pixels; 

------

### Normal

**Normalized pixel texture for individual zones**

`execute = normal`

As the *texture* process does, *normal* returns  the mean difference between all pixel pairs within an individual zone but in this case the difference is normalized by the mean brightness of the compared pixels. 

​	![image-20240320114238721](/home/c7sepe2/ESIS/GitHub_Commands/8_normal.png)	vi: pixel value; vj: neighbor pixel value; b: bands

------

### Dendrites

**Quotient of zone perimeter and cellsize**

`execute = dendrites`

*Dendrites* returns the quotient between perimeter and size of single zones. Both values grow with larger zones but the size grows faster. Large zones will show lower values than smaller ones with the same shape.

​	![image-20240320114514035](/home/c7sepe2/ESIS/GitHub_Commands/8_dendrites)	vr: Result Value; pz: Perimeter (zone); sz: Size (zone)

------

### Diversity

**Spectral diversity of the central zone and all neighbors**

`execute = diversity`

The spectral diversity between zones is calculated as the statistical deviation of all color attributes between the central zone and all its neighbors. As the zones might differ considerably in size and shape the length of the common border was selected as a measure for the contribution of the peripheral zones to the final value. 

​	![image-20240320115214090](/home/c7sepe2/ESIS/GitHub_Commands/8_diversity.png)	vi: Pixel value; vn: Neighbor value; bp: Pixel boundaries

------

### Proportion

**Size diversity of the central zone and all neighbors**

`execute = proportion`

*Proportion* returns the relation between the size of the central zone and all its neighbors. The result is calculated as difference between the size of the central zone and the mean size of its neighbors. As the size is given in a logarithmic scale, the “mean” is not an arithmetic but a geometric mean. Values around zero indicate equally sized neighbor zones. 

​	![image-20240320115439083](/home/c7sepe2/ESIS/GitHub_Commands/8_proporion.png)	si: Size, central zone; sj: Size, neighbor zone; n: number of neighbors

------

### Relation

**Quotient of neighbors and perimeter of one zone**

`execute = relation`

*Relation* is calculated as the relation between the number of neighbor zones and the perimeter of the central zone. Like *dendrites* also *relation* returns information about the shape and the connection of the zones. Zones with many connections may provide paths for animal travels and enhance diversity.

​	![image-20240320115912653](/home/c7sepe2/ESIS/GitHub_Commands/8_relation.png)	r: relation; c: number of neighbors; p: perimeter

------

### Cellsize

**Size of the zones given as [ha]**

`execute = cellsize`

The size of the zones is calculated as the sum of all pixels covering the zone. The values are given as Hectares [ha] (100m × 100m). 

​	![image-20240320120223601](/home/c7sepe2/ESIS/GitHub_Commands/8_sellsize.png)	Sp: pixel size [m]; Sz: pixel per zone; 

------

### Diffusion

**Emphasize local maxima and minima for all features**

`diffusion = number of iterations`

The *diffusion* process is only controlled by the number of iterations. Each iteration enlarges the region of contributing zones. The influence of distant zones on the central zone decreases with distance. Entries over 10 are still allowed, but rarely have a visible effect.

​	![image-20240320120444688](/home/c7sepe2/ESIS/GitHub_Commands/8_diffusion.png)	a: attribute value; s: zone size; c: pixel contacts; i,j: zone indices; t: iterations (time)

------

### Values

**Raster representation of a vector map with attributes**

`execute = values`

The *values* process creates a multi band raster image from the geometry and the attributes of the different polygons. *Values* mainly serves as a control feature. 

### Example

```
IMALYS [features]
…
features
	select=compile
	execute=cellsize
	execute=dendrites
	execute=diversity
	execute=entropy
	execute=normal
	execute=proportion
	execute=relation
	values=true
```

This example creates a new feature set from spectral and geometry features. Spectral features are taken from the predefined selection “compile”, seven textural and morphological features are added. Features can be selected without restrictions.

-----

[Index](0_Index.md)