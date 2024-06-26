## T6	Export Formatted Results

[Export](../manual/11_Export.md) allows to save internal results to a selected place. *Imalys* stores the results of all processes to the working directory. Images are stored in the ENVI format, vector data and tables use the WKT format. Both formats support fast and easy processing. During *export* the data can be translated to a variety of other formats. The format is controlled by the given extension.

```
IMALYS [example 6]
…
export
	select = mapping
	target = /home/»user«/ESIS/fabric_classes.tif
export
	select = index
	target = /home/»user«/ESIS/fabric_zones.shp
```

Tutorial 5 shows how the [export](../manual/11_Export.md) command depends on the context. It basically adopts the result of the last given command and saves it in the selected format. The export format is controlled by the extension in the result name. *Export* can be repeated after each command to save new results.

Special conditions apply to zones, classes and vectors.

-----

[Previous](5e_Compare.md) – [Index](Index.md) – [Next](7a_Variables.md)

