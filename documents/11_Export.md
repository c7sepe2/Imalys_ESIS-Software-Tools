## Export	

**exports layers from the working directory**

The result of the process chain can be exported from the working directory to any other place. During *export* the image or vector format can be selected. Classified images can be exported as attributed polygons. In all cases the extension of the target filename controls the format of the export.

------

### Select

**Select a raster or vector layer to be exported**

`select = filename`

Each raster or vector layer at the working directory can be selected. The export will transform the result according to the file name extension of the *target*. A classified raster layer can be exported to a vector layer.

- Mapping results will be export together with the binary class definition (BIN format).
- Zones must be selected as “index” and will be transformed to attributed polygons according to the selected vector format.

------

#### Target

**Selects filename and format of the output file(s)**

Raster based results can be exported to 48 different raster formats. Raster export includes results from vector based processes. Without extension the format is ENVI labelled.
Vector based results can be exported to 23 different vector formats. Vector export includes automated transformation for classified raster data. Standard format is ESRI Shape.

```
export
	select=index
	target=/home/*user*/ESIS/results/München.shp
```

The internal zone files are selected by *index* and exported to the *results* folder using the ESRI shape format. 
