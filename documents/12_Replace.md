## Replace	

**replace variables given in the process chain**

To manage long process chains and to repeat identical processes with different input data *Imalys* allows to use variables within the process chain. Variables consists of a “$” sign followed by one figure from 1 to 9. Variables can be defined either at the beginning of the process chain or in a separate variable list. The latter allows repeated processing of the whole chain with changing input (repeat mode).

To operate the repeat mode, *Imalys* must be called with *r_Imalys* and two parameters. The first must be the name of the process chain, the second the variable list. *r_Imalys* will repeat the process chain once again for each line in the variable list without any further interaction.

------

### Replace

**Replace locally defined variables**

`$1 … $9 = string`

If a process chain should be used for different tasks, the command chain can use local variables. Imalys will substitute each variable with the assigned value. To recall a tasks with different parameters only the variables have to be changed. Variables can be part of each command chain (Hook)

------

### Repeat

**Replace variables using a value list**

```
var_1	var_2	…
var_1	var_2	…
…
```

To operate a large amount of different tasks, the variables can be given by a text file that contains only the variables. All variables for one run must be given in one line and separated by tabs. The columns represent the variable number. Higher variable numbers will not be affected. Both variable definitions can be combined if higher numbers are assigned directly.

------

### Examples

```
IMALYS [replace]
replace
	$1 = c7934
	$2 = München
home
	directory = /home/»user«/.imalys
	clear = true
	log = /home/»user«/ESIS/Results/$1_$2
.. commands ..
```

The first example produces the same results as the example under [Home](1_Home.md). In this case the two variables *$1* and *$2* are exchanged during processing.

```
IMALYS [repeat]
home
	directory = /home/»user«/.imalys
	clear = true
	log = /home/»user«/ESIS/Results/$1_$2
.. commands ..
```

```
c3922	Hannover
c4738	Leipzig
c5142	Chemnitz
c7934	München
```

The second example shows a process chain (upper) and a variable list (lower). All variables for one run of the process chain must be given in one line. Each line will induce another run of the process chain. In his case the process chain will be repeated for the four cities Hannover, Leipzig, Chemnitz and München. The example must be called as

`r_Imalys ProcessChain VariableList`

-----

[Index](0_Index.md)