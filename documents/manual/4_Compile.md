## Compile	

**Select, translate and stack bands or images**

Most of all *Imalys* commands need one image stored at the working directory as input. The *compile* command translates all selected images to a common format, stacks them to a multi layer image and stores the stack as *compile* at the working directory. The compilation ensures that all selected bands share the same format, projection, pixel size and frame. 

The images can be selected by a time period (*period*), by a filename (*select*) or a search string with wildchars (*search*). The result can be masked to a common *frame*. If the selected images differ in projection or pixel size they must be harmonized with *warp* or *pixel* under the [import](3_Import.md) command. 

------

### Select

**Select images by their filename**

`select = image filename`

*Select* can be repeated as often as necessary. All selected images will be stacked. The *select* parameter can be repeated as often as necessary. *Select* can be combined with *search* and *period*. 

------

### Search

**Select images using a search string**

`search = image filename with wildchars`

A search string using system wildchars (*,?) is used to select appropriate images. Variable and fixed parts of the filenames can be used as needed. The *search* parameter can be repeated as often as necessary. *Search* can be combined with *select* and *period*.

------

### Period

**Select images of a given time period**

`period = YYYYMMDD – YYYYMMDD`	(Y=Year; M=Month; D=Day)

*Period* selects all images stored at the working directory that fit the given period. The *period* parameter can be repeated as often as necessary. *Period* can be combined with *search* and *select*.

------

### Frame

**Cut the result to a given polygon**

`frame = geometry filename`

If the selected images have different coverages or the result should be restricted to a specified area the *frame* parameter will clear all image parts outside of the passed *frame*. The *frame* can take any shape.

------

### Projection

**Override the projection of the selected image**

`projection = image filename`

If “pure” images should be combined with projected ones, the “pure” image can take the coordinates of a projected one. The option only needs the filename of the projected image. "Projection" takes the top left corner and the pixel size from the passed template.

------

### Format

**assign a selected image format**

`format = true`

As a standard procedure all image values are transferred to a 32 bit float format. To use classified images, the standard procedure can be overridden by the *format* parameter. At the moment *format* will preserve the format of the selected image. 

------

### Target

**Assign a filename for the compiled image stack**

`target = image filename`

The *target* option renames the result of the compile command. The parameter was introduced if two compile commands should be given in succession.

------

### Example

```
IMALYS [compile]
…
compile
	period = 20220501 – 20220731
```

This first example stacks all images taken between May and July. The images are taken from the working directory. As no target name is given the result is named “compile” and stored at the working directory.

```
IMALYS [compile]
…
compile
	search = /home/*user*/ESIS/results/*2022*.tif
	frame = /home/*user*/ESIS/frames/c4738.gpkg
	target = Leipzig_2022
```

The second example stacks all images taken at 2022 from the “results” directory and cuts them to the frame “c4738” and stored them to the working directory. The result is called "Leipzig_2022". The “TIFF” format is converted to “ENVI” during the stacking process. 

-----

[Previous](3_Import.md)	–	[Index](Index.md)	–	[Next](5_Reduce.md)