## Run Imalys

*Imalys* has a large number of commands and parameters due to the variety required. Commands summarize basic functions, parameters select processes and accept inputs. *Imalys* must be called using a shell or terminal.  To simplify the call, all commands and parameters for an entire process chain are given by one text file.

The call consist of the executable file *x_Imalys* and the name of a text file (*process chain*) containing commands and parameters. If the process chain should be repeated with different variable sets, *r_Imalys* must be called with two parameters. The first is the process chain, the second is another text file (*variable list*) containing only the different variable sets (see [Replace](12_Replace.md)).

`x_Imalys /home/»user«/ESIS/hooks/commands`

`r_Imalys /home/»user«/ESIS/hooks/commands /home/»user«/ESIS/hooks/variables`

The example calls *Imalys* with the process chain *commands* or repeat the process chain with variable sets given by *variables*

-----

[Previous](12_Replace.md)	–	[Index](Index.md)	–	[Next](1_Home.md)
