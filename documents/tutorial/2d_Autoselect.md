### T2d	Import with an Image Catalog

The image catalog was designed to select appropriate image tiles out of a large collection of archives. 

If a *frame* is given, only tiles that cover or touch the frame will be selected. The ***distance*** parameter controls the relative distance between the center points of the image and the given frame. With *distance = 1* the image must cover at least half of the frame. For larger frames at least half of the image must covered by the frame. Smaller inputs will force higher coverages. The parameter *period* defines a schedule for the acquisition time. 

Sometimes large parts of the image tiles are empty. The parameter ***cover*** checks the coverage of the given frame by the defined parts of the image. The *quality* process will check values and status of each pixel within the frame. This check needs considerable processing time. The preselection of appropriate image tiles speeds up the import for several times.

After the selection of appropriate archives *Imalys* checks the image quality of the selected frame. ***Quality*** checks if parts of the defined image shows clouds or other disturbances and limits the proportion of “bad” pixels within the given frame.

```
IMALYS [tutorial 2d]
home
	directory=/home/»user«/.imalys
	clear=true
	log=/home/»user«/ESIS/results
import
	database=/home/»user«/ESIS/archives/center.csv
	distance=1.00
	period=20220501-20221031
	frame=/home/»user«/ESIS/frames/bounding-box.shp
	cover=0.9
	quality=0.86
	bands=_B2, _B3, _B4, _B5, _B6, _B7
	factor=2.75e-5
	offset=-0.2
	warp=32632
	pixel=30
```

»user« must be exchanged with the home directory of the user!

---

Tutorial 2d	uses an image [Catalog](../manual/2_Catalog.md) to import all example images. [Home](../manual/1_Home.md) clears the working directory, the archive selection is set to a acquisition date between May and October and an assured coverage (*distance=1*). The result images must be covered at least by 90% of each accepted image (*cover=0.9*), the cloud cover must be less than 15% (*quality=0.86*). Everything else is like tutorial 2b.

-----

[Index](Index.md)