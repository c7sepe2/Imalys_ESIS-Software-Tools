## Catalog

**Create a position and size database for image archives**

The Catalog command was implied to select appropriate archives for an [Import](3_Import.md) process effectively. *Import* can address archives directly using *select* but with less comfort. The resulting database is a point geometry (using WKT format) that includes the center point of each image tile, the distance to the tile center and the filename. The database can be visualized using a GIS. The database is always created for the specified directory.

------

### Archives

**Select a directory and a subset of an image archives collection**

`archives = filename with wildchars`

A filename mask *archives* must be given to select the directory and can also be used to select sensor types or specific tiles. All archives that share the given mask will be accepted. 

```
IMALYS [catalog]
…
catalog
	archives = /home/»user«/ESIS/archives/LC0*
```

This command will select all Landsat 8/9 archives in the users directory ESIS/archives.

------

[Previous](1_Home.md)	–	[Index](Index.md)	–	[Next](3_Import.md)

