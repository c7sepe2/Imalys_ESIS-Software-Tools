### T7b	Process repetition

Variables can also be used to repeat a whole process chain with different inputs and produce corresponding outputs without further interaction. In this case *r_Imalys* has to be called with two parameters, the process chain and a variable table.

**Attention:** This example requires additional image data and frames of four German cities! They are not included in the tutorial data.

```
r_Imalys /home/»user«/ESIS/hooks/example_7b /home/»user«/ESIS/hooks/variables_7b
```

The process chain needs no variable definition

```
IMALYS [example 7b]
home
	directory=/home/»user«/.imalys
	clear=false
	log=/home/»user«/ESIS/results
catalog
	archives = /home/»user«/ESIS/archives/*_L2SP_*
import
	database = /home/»user«/ESIS/archives/tilecenter.csv
	distance = 1.00
	frame = /home/»user«/ESIS/frames/$1.gpkg
	quality = 0.86
	bands = _B2, _B3, _B4, _B5, _B6, _B7
	factor = 2.75e-5
	offset = -0.2
reduce
	select = import
	execute = bestof
export
	select = bestof
	target = /home/»user«/ESIS/results/$1_$2.tif
```

*Database* includes all Landsat archives in the given directory. *Distance = 1* acts as a preselection. Only archives that reach the center of the given *frame* will be extracted. The second step of the selection is done by *quality = 0.86*. The parameter will limit the cloud cover to a maximum of 14% but will also reject tiles with less than 86% of usable pixels within the *frame*.

```
c3542	Berlin-West
c3546	Berlin-Mitte
c4738	Leipzig
c6730	Nürnberg
```

Example 7b shows how to repeat a process chain (above) for different maps. The *frames* for the image import and the names of the resulting images (*target*) must be given by the variable table (above). The imported images are reduced to one median image (*bestof*) and exported as GEO-Tiff with the name of the map and the city like *c4738_Leipzig.tif*.

The variable table only contains the values. All variables for one run of the process chain must be given in one line. Each line will induce another run of the process chain. The variables are divided by tabs. The columns represent the numbers of the variables starting with "1".

In this case the process chain will be repeated for the cities of Berlin-West, Berlin-Mitte, Leipzig and Nürnberg.

-----

[Index](Index.md)

