## T7	Process Chain Variables

The process chain can use variables instead of parameters. A “$” sign followed by a single number will be interpreted as a variable. Variables can be used for different purposes:

- Long filenames can be substituted by a short expression
- All input parameters for a given process chain can be concentrated at the beginning of the process chain
- A list of parameter sets can be given to repeat a process chain for different input data without manual interaction
- Image selection can depend on variable parameters

-----

### T7a	Internal variables

Internal variables must be defined at the beginning of the process chain. Each occurance of the variable will be exchanged by the defined string.

```
IMALYS [example 7a]
replace
	$1 = c7106
	$2 = Leipzig
home
	directory = /home/»user«/.imalys
	clear = true
	log = /home/»user«/ESIS/results/$1_$2
```

will replace the last line to

```
	...
	log = /home/»user«/results/c7106_Leipzig
```

Tutorial 7a shows how a variable definition under *replace* is exchanged in the last command line of the example. Each variable of the whole process chain is replaced in the same way.

-----

[Index](Index.md)

