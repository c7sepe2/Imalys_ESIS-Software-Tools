## Reduce	

**reduce image dimension by pixel based processing**

The reduce command summarizes all processes that reduce the number of bands in an image. Reduce includes band proportions like the vegetation index NDVI, statistical processes like the variance of a time course and quality issues like the median of an image collection. 

The *NirV*, *NDVI*, *EVI* and *LAI* index are proxies for biomass and mainly the metabolism rate of green plants. About 20 different approximations are described¹, some of them differ in details². The NirV index tries to quantify the photosynthetically active radiation (PAR) as a measure of plant metabolism³ that might be most important for the evaluation of environmental services.

The statistical processes *mean*, *difference*, *brightness*, *variance* and *regression* are calculated as defined. For multispectral images the result of each band is calculated separately. The result can be stored as a multispectral result or as a single layer using the *flat* option. The *regression* depends on precise timestamps. Using the [import](3_Import.md) command the acquisition date is registered at the images metadata. 

The *mean*, *median* and *principal* processes can be used for quality enhancement. The *bestof* process is a mixture of them that tries to select the most reliable combination of several images. *Bestof* relies on a quality indicator of the selected frame taken from the providers metadata. This indicator allows to decide wether a single but undisturbed image, the mean of two images or the median of three or more images is used for the result. The three options are evaluated individually for each pixel.

The *principal* component rotation tries to extract the most significant image properties to a smaller number of bands. The feature space is rotated to show a maximum of differences, the differences are stored as a new layer and the extracted layer is deleted from remainings. The process is repeated for the each result band.

*Reduce* accepts more than one *execute* call for the same image. All results are stored at the working directory and named as the process.

#### select

**Mark one image of the working directory to be processed**

`select = image filename`

More than one image can be processed at the same time if they are stacked using the [compile](4_Compile.md) command

#### variance

**Variance based on standard deviation**

`execute = variance`

The *variance* parameter determines the variance of individual pixels based on a standard distribution for all individual bands in the source image. The process returns a multispectral image of variances. If the *flat* parameter is added, the result will be reduced to one band.

​	![image-20240319181352369](/home/c7sepe2/snap/typora/86/.config/Typora/typora-user-images/image-20240319181352369.png)	v: values; i: items; n: item count

#### regression

**Regression based on standard deviation**

`execute = regression`

The *regression* parameter returns the regression of individual pixels of all bands in source. *Regression* tries to use the temporal distance of the recordings from the metadata of the images. To do this, the images must have been imported with the [import](3_Import.md) command. The process returns a multispectral image of regressions (see *variance*). Using the *flat* option the result is further reduced to one band.

​	![image-20240319181602245](/home/c7sepe2/snap/typora/86/.config/Typora/typora-user-images/image-20240319181602245.png)	t: time; v: values; i: items; n: item count

#### flat

**Reduce all results to one band**

`flat = true`

The *flat* process uses the first principal component of all bands to reduce a multispectral result to one band showing the overall brightness.

​	<img src="/home/c7sepe2/snap/typora/86/.config/Typora/typora-user-images/image-20240319181755114.png" alt="image-20240319181755114" style="zoom:80%;" />	v: values; i: items

#### difference

**Euklidian distance of two (multiband) images**

`execute = difference`

The process returns the difference between two images. The result a multispectral image of differences. Using the *flat* option the result is further reduced to one band.

​	![image-20240319182407876](/home/c7sepe2/snap/typora/86/.config/Typora/typora-user-images/image-20240319182407876.png)	v: pixel value

#### NirV, NDVI, EVI

**Near infrared vegetation index (NIRv)**
**Normalized vegetation Index (NDVI)**
**Enhanced vegetation index (EVI)**

`execute = NirV | NDVI | EVI`

Both the NIRv and the NDVI index are calculated as the product of near infrared radiation and the normalized difference of the red and the near infrared radiation. The NirV definition shows a better mapping at sparsely vegetated areas.

NirV: ![image-20240319182841085](/home/c7sepe2/snap/typora/86/.config/Typora/typora-user-images/image-20240319182841085.png)	N: Near infrared value; R: Red band value

#### LAI (deactivated)

**Leaf cover per area**

`execute = LAI`

The *LAI* parameter gives the proportion of leaf surface compared to the ground surface covered by the plants. The LAI was introduced as a proxy for field work. Simulated LAI values by means of remote sensing are of minor quality.

#### brightness

**First principal component of all bands**

`execute = brightness`

The process returns the brightness of all bands in the passed image. For multispectral images, the *brightness* is individually calculated for each band. The result is one multispectral image with the the first principal component of each band. Using the *flat* option the result is further reduced to one band.

​	![image-20240319183231922](/home/c7sepe2/snap/typora/86/.config/Typora/typora-user-images/image-20240319183231922.png)	v: values; i: items; 

#### principal

**Principal component rotation**

`execute = principal`

The process extracts the first *count* principal components from a n-dimensional image. The process tries to extract the most significant image properties to a smaller number of bands. 

#### count

**Image dimensions after principal component rotation**

`count = number_of_dimensions` (bands)

only together with *principal*

The *count* parameter restricts the rotation to *count* steps. Without *count* the result of the rotations has one dimension less than the original.

#### mean

**Arithmetic mean of all bands**

`execute = mean`

The *mean* parameter gives the arithmetic mean of all image bands provided. For multispectral images, the result is individually calculated for each band. The process returns a multispectral image of mean values (see *variance*). Using the *flat* option the result is further reduced to one band.

​	![image-20240319183835174](/home/c7sepe2/snap/typora/86/.config/Typora/typora-user-images/image-20240319183835174.png)	v: values; i: items; n: item count

#### median

**Most common value for each pixel from a stack of bands**

`execute = median`

The median reflects the most common value of each pixel in a stack of bands or images. The process returns a multispectral image of most common values. Using the *flat* option the result is further reduced to one band. The *median* process can mask rare values. Clouds or smoke will disappear if more than the half of all pixels show undisturbed values.

​	*Value in the middle of a sorted value list.*

#### bestof

**Automatically choose the most appropriate generalization**

`execute = bestof`

The *bestof* process returns an optimized image from one or more images with lesser quality. The typical import is a short time course. *Bestof* works better if the input images show no holes.

#### target

**Rename the result of the last command**

`target = filename`

The *target* option renames the result of the last command. The new name is restricted to the working directory. Only the last result will be modified. Choose the [export]() command to store one or more results at a different place.

#### Example

```
IMALYS [reduce]
…
reduce
	select=compile
	execute=bestof
	target=summer
reduce
	select=summer
	execute=NDVI
	red=2
	nir=3
	target=NDVI
```

In this example two *reduce* processes follow each other. The first reduces the result of the last [compile](4_Compile.md) command to one multispectral image. This does only make sense if the result of the image *compile* consist of several images (see second example under [compile](4_Compile.md)). 

A *target* is given to rename the result of the reduction. Without a *target* the second *reduce* process would override the result of the first. The second *reduce* uses the result of the first to calculate the normalized vegetation index. 

Files stored in the working directory can be called only by their name.
