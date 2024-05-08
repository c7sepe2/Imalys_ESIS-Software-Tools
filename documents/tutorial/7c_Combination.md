### T7c	Combine database, filter and repetition

A process chain can include repetition and several processes. In this case the archives of different cities are extracted using a *database*  and the result is combined to two images of each city.

```
IMALYS [example 7c]
home
	directory=/home/»user«/.imalys
	clear=false
	log=/home/»user«/ESIS/results
import
	database = /home/»user«/ESIS/archives/tilecenter.csv
	distance = 1.00
	frame = /home/»user«/ESIS/frames/$1.gpkg
	quality = 0.86
	bands = _B2, _B3, _B4, _B5, _B6, _B7
	factor = 2.75e-5
	offset = -0.2
	warp = 32632
	pixel = 30
compile
	period = 20110501 - 20110730
reduce
	select = compile
	execute = bestof
export
	select = bestof
	target = /home/»user«/ESIS/results/$1_$2_May-July.tif
compile
	period = 20110801 - 20111031
reduce
	select = compile
	execute = bestof
export
	select = bestof
	target = /home/»user«/ESIS/results/$1_$2_Aug-Oct.tif
```

-----

[Previous](7b_Repetition.md) – [Index](Index.md) – [Next](Index.md)
