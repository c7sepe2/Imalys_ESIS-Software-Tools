### T2e	Select and reduce a short time course

Time periods can be selected during the image [Import](../manual/3_Import.md) but as well with the [Compile](../manual/4_Compile.md) command if imported images are available. The selection will only work if the acquisition time is part of the image filename.

```
IMALYS [tutorial 2e]
home
	directory=/home/»user«/.imalys
	log=/home/»user«/ESIS/results
compile
	period=20220801-20221031
reduce
	select=compile
	execute=bestof	
export
	select=bestof
	target=/home/»user«/ESIS/results/bestof_autumn.tif
```

»user« must be exchanged with the home directory of the user!

---

The results of tutorial 2d must be available at the working directory!

Tutorial 2e is nearly identical to tutorial 2b except the time period under [Compile](../manual/4_Compile.md) and [Export](../manual/11_Export.md). The result of T2e is an 6 band image of the second half of the vegetation period of 2022. 

----

[Previous](2d_Autoselect.md) – [Index](Index.md) –[ Next](3a_Vegetation.md)

