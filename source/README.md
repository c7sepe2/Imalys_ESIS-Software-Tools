### Imalys Software Library

The *Imalys* sources are completely provided in this directory. 

The software library includes two projects *x_Imalys* and *r_Imalys*. *x_Imalys* executes a given process chain (hook), *r_Imalys* repeats the *process chain* for each variable set given by a *variable list* (see [tutorial](./documents/tutorial/README.md) or [manual](./documents/manual/Index.md)). Both processes use the same units. The code is written in [Free Pascal](https://www.freepascal.org/) and compiled under Linux/Ubuntu. There is a Free Pascal user group at [GitLab](https://gitlab.com/freepascal.org/fpc/). 


The project files *x_Imalys.lpr* and *r_Imalys.lpr* are designed using [Lazarus](https://www.lazarus-ide.org/). Please be aware that the project files include my personal paths and must be modified. To run under a server environment *Imalys* does not call any graphical objects. As the code is written for Linux, some system calls will not work using Windows. 

The units *custom* and *loop* parse the given parameters and control the process chain. They are called by *x_Imalys* and *r_Imalys*. All other units (*raster, format, mutual, thema, index, vector*) provide the process steps. 
