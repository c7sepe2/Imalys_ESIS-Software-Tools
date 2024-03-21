## Compare	

**validate and / or assign classes**

The self adjusting classification [mapping](9_Mapping.md) is driven by image features. Real classes are not necessarily defined by their appearance. *Compare* allows to evaluate if and up to witch degree real classes can be detected by image features. The main result is a confusion matrix for false and true detection and denotation. The result can be used to assign class names and get a confidence level to the statistical outcome of the [mapping](9_Mapping.md) process. The comparison is done by a rank correlation that will be independent from the value distribution.

The standard result of *compare* command is an accuracy table. Using the *control* option, an image *accuracy* is created at the working directory, that shows only accurate classification results and gives an impression of spatial distribution of the errors. Besides the image a table *combination* with all links between reference and classification and a table *specifity* with more accuracy measures are created. 

***Caution: Compare works but is not checked under different conditions***

------

### Reference

**Selects a class reference (raster or vector)**

`reference = filename`

Reference classes are assigned to the [Mapping](9_Mapping.md) results by means of a rank correlation after Spearmann. A rank correlation is independent of the basic value distribution. Therefore it can be used for each set of data, even a mix of form and spectral features.

​	![image-20240320133435426](/home/c7sepe2/ESIS/GitHub_Commands/10_Rank.png)	r,s: item rank; i: item index; n: items count

------

### Raster

**Stores a vectorized classification to a raster layer**

`raster = true`

Vector layers can not be compared directly. The *raster* option allows to save the class reference data to a raster image.  

------

### Fieldname

**Marks a field in the reference table that contains class names**

`fieldname = table_field_name_with_class_names`

The option *fieldname* marks the equally called column in the reference data as class names of the reference.

------

### Assign

**Assign class names from a reference classification**

`assign = true`

The option *assign* transfers the class names of the references to the results of the compare process

------

### Control

**Stores additional accuracy information**

`control = true`

The *control* option creates an image *accuracy* at the working directory where only accurate classification results are depicted, a table *combination* with all links between reference and classification and a table *specifity* with more accuracy measures. 
generic

-----

[Index](0_Index.md)
