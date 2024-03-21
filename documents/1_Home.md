## Home

**Create or select an *Imalys* working directory**

*Imalys* needs the name of a working directory. *Imalys* uses large matrix transformations. To get sufficient speed, a quick local memory should be assigned as a working directory. If several process chains are called at the same time, each chain needs a separate working directory. The first word of the first line of the process chain must be “IMALYS”. The remainder of the first line is ignored and can be used for hints.

Final results can be stored with the [export](11_Export.md) command at a different place. Using the *log* parameter messages and warnings are directed to the passed directory. We strongly recommend to store final results and messages at the same place. 

------

### Directory

**Assign or create a working directory**

`[directory = filename of the working directory]`

*Imalys* will initially save all results in the working directory. The result will be named as the command. If no working directory is given, *Imalys* tries to create a `~/.imalys/` directory at the users home.

------

### Clear

**Clear the working directory**

`[clear = true | false]`

Most processes will produce various intermediate results. If the final result of the last run is stored at a separate directory, the working directory should be cleared at the beginning of each process chain.

### Log

**Set a message directory**

`[log = pathname]`

*Imalys* reports each command, returns an activity log for all processes and lists error messages. The error list includes error messages from other software called by *Imalys*. If no *log* is given, the messages are stored at the working directory.

```
IMALYS [home]
home
	directory = /home/»user«/.imalys
	clear = true
	log = /home/»user«/ESIS/Results/c7934_München
```

In this case the default working directory is used but the messages are directed to a results directory. “IMALYS” at the beginning of the first line is mandatory. The remainder of the line is ignored and can be used for hints

------

[Index](0_Index.md)
