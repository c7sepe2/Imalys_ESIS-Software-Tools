### T2c	Image collection database (catalog)

*Imalys* can create a local image archives database to select images effectively. The database stores the acquisition date together with the center and the size of the archived image tiles. The database is formatted as point geometry to have a look at it using a GIS. 

There is no need to call the [catalog]() in the same process chain as the [import](../manual/3_Import.md). The *catalog* must only be recalculated if the collection of archives has changed.

```
IMALYS [tutorial 2c]
home
	directory=/home/»user«/ESIS/.imalys
	clear=true
	log=/home/»user«/ESIS/results
catalog
	archives=/home/»user«/ESIS/archives/*_L2SP_*
	target=/home/»user«/ESIS/archives/center
```

»user« must be exchanged with the home directory of the user!

---

Tutorial 2c creates a position and size database of all archives at the directory *archives* and stores it as *center.csv*. The accepted archives can be filtered using a usual file name filter like *_L2SP_* for Landsat level-2 products. 

-----

[Previous](2b_Quality.md) – [Index](Index.md) – [Next](2d_Autoselect.md)
