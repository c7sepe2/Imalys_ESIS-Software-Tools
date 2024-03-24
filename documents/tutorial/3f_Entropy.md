### T3f	Rao’s Entropy

Texture as a measure of diversity has the disadvantage that even a monoculture can show a high texture due to a “rough” surface. Rao’s entropy evaluates spectral and spatial differences simultaneously. Regular patterns show lower values than the classical texture. The main concept is to compare each pixel with each other in a given kernel [4] [6]. Thus regular pattern with high texture like a forest canopy will show low to moderate diversity. Random distribution will show the highest values *Entropy*.

*Imalys* implements three different versions of Rao’s approach. The kernel-oriented versions *deviation* only differs a little from texture in practice. The class-oriented version *entropy* is closer to the biological definition, but requires a land cover classification. The best results can be achieved with [zones]() and the *entropy* process for zones.

Using single pixels the calculation is quite demanding. If a spectral classification is available, the same process is much quicker. The [mapping]() command with *entropy* as a parameter calculates both, the classification and Rao’s Entropy.  

```
IMALYS [deprecated example 3f “entropy”]
home
	directory=»user«.imalys
	clear=false
	log=/home/»user«/ESIS/results
compile
	select=/home/»user«/ESIS/results/B234567_20220501-20220731.tif
	select=/home/»user«/ESIS/results/B234567_20220801-20221031.tif
mapping
	select=compile
	model=pixel
	features=30
	samples=30000
	execute=entropy
	radius=2
export
	select = entropy
	target = /home/»user«/ESIS/results/Entropy.tif
```

»user« must be exchanged with the home directory of the user

the result of the tutorial 3d must be retained (*clear=false*)

-----

Tutorial 3f shows how to use the self adjusting classification ([mapping]()) as an input to calculate Rao’s Entropy. *Mapping* creates a spectral classification with 30 different clusters based on 30,000 samples. The *model*, *features* and *sample* parameters are default and can be modified if necessary. The *entropy* process depends on the classification and can only be induced under *mapping*. The classification result and the class definition is stored as “mapping” in the working directory and can be used for other purposes.

The classification needs no references because Rao’s entropy only needs the frequency of the different classes within one kernel an the spectral differences between the them. Rao’s entropy can only be retrieved under [mapping](), since classification and diversity have to be computed together. The classification command *mapping* needs additional parameters but the defaults will work in almost any situation.

-----

[Previous](3e_Entropy.md) – [Index](Index.md) –[ Next](4_Zones.md)
