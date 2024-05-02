## T1	Get the Imalys tutorials

------

### T1a	Download the tutorial

- Create a new directory *ESIS* at your home directory
- Add the subdirectories *archives*, *frames*, *hooks* and *results* 
- Download and extract the [image frames](../images/frames.zip) archive to your *~ESIS/frames* directory
- Download the following [USGS Landsat atchives](https://earthexplorer.usgs.gov/) to your *~/ESIS/archives* directory:

LC08_L2SP_193026_20220515.tar; 
LC08_L2SP_193026_20220531.tar; 
LC08_L2SP_193026_20220702.tar; 
LC08_L2SP_193026_20220718.tar; 
LC08_L2SP_193026_20220803.tar; 
LC09_L2SP_193026_20220811.tar; 
LC09_L2SP_193026_20220912.tar; 
LC09_L2SP_193026_20221030.tar; 

If you prefer to install the tutorial to another directory, you will have to modify the path names at the examples.

------

### T1b	Install executable files

All commands and processes of ***Imalys*** are combined into an executable program *x_Imalys*. *x_Imalys* does not need to be installed. It is sufficient to copy [x_Imalys](../../binaries/x_Imalys) and [r_Imalys](../../binaries/r_Imalys) to your *usr/local/bin* directory. You will need administrative rights to copy them. The *usr/local/bin* directory is not included into the package system.

```
sudo cp ~/downloads/x_Imalys usr/local/bin
sudo cp ~/downloads/r_Imalys usr/local/bin
```

If you prefer to install the executable files to a subdirectory of your */usr/local/bin* do not forget to extend your environment for the selected path.

Imalys uses the **GDAL library** of the [Open Source Geospatial Foundation](https://www.osgeo.org/) for a lot of processes. This library must be installed under */usr/bin*. For many Linux distributions this is already the case. Alternatively GDAL can be installed from [GitHub](https://github.com/OSGeo/GDAL). If you run QuantumGis the GDAL library is already installed.

-----

### T1c	Run executable files

The executable files *x_Imalys* or *r_Imays* must be called as a command in a shell or terminal. *x_Imalys* must be called with one parameter containing the filename of the process chain (see manual [Execute](../manual/0_Execute.md)). To repeat the process chain with varying parameters, *r_Imalys* must be called with the filename of the process chain and the variable list as parameters (see tutorial [Process Chain Variables](7a_Variables.md)). 

```
x_Imalys »path_to_process-chain«
r_Imalys »path_to_process-chain« »path_to_variable-list«
```

-----

### T1d	Initialize Imalys processes

To simplify long process chains, all commands and parameters are given in one text file or hook. The first entry is always the *home* command with information where to store intermediate data and where to store the metadata.

```
IMALYS [example 1d]
home
	directory = »user«/.imalys
	clear = true
	log = »user«/ESIS/results
```

»user« must be exchanged by the users home directory

The [home](../manual/1_Home.md) command and *IMALYS* at the beginning of the first line is mandatory for each process chain. »user« stands for the home directory of the user. All examples will use the default working directory *»user«/.imalys*. The directory is cleared it at the beginning of the process chain. The directory *results* is assigned to store messages and metadata. Each process and many sub-steps return messages about the progress of the processing. We recommend to store these files together with the results.

-----

### T1e	General syntax of the process chain

The **process chain** passed to *x_Imalys* must contain commands and their parameters. The processes can be combined as necessary but the internal logic of the process chain is up to the user. The *home* command to create or assign a working directory at the beginning of the process chain is mandatory. 

Each command and each parameter needs a separate line. A single word in one line is interpreted as process name. Lines with a “ = ” character are interpreted as “parameter = value” pair. Parameters always have a preset. It is changed by the entry in the text. Only the “select” parameter to assign an appropriate input for each process is mandatory. 

Everything after the "#" character is interpreted as a **comment** and ignored until the end of the line.

The **working directory** was implemented to enable the rapid processing of data that may only be available through a service or a slow connection. It should be directly accessible. The process chain is bound to the working directory. It can be created or emptied at the beginning of the chain and stores all intermediate results. Each instance of *Imalys* needs its own working directory. 

Besides the *export* command each process stores the results to the working directory. The **result file name** is the same as the process name. If the results are transferred to tables, the process name also serves as field name. Therefore process names are short and can have a much wider meaning in general usage. 

The result names can be changed using the *target* command. Existing files will be overwritten without warning. All images are stored as raw binary with ENVI header. Imalys thus complies with the requirements of the European Space Agency (ESA). Geometries use the WKT-format.

-----

[Previous](Index.md) – [Index](Index.md) –[ Next](2_Import.md)

