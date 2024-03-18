## Imalys – ESIS tool for Image Analysis

![tools](images/tools.svg) under construction

In the ESIS project [XYZ] we are trying to put environmental indicators on a well-defined and reproducible basis. The *Imalys* software library is supposed to generate the remote sensing products defined for ESIS. The library provides tools to select, extract, transform and combine raster and vector data. Image quality, landscape diversity, change and different landuse types can be analyzed in time and space. Landuse borders can be delineated and typical landscape structures can be characterized by a self adjusting process.

Most of the methods and analyses implemented in *Imalys* are also available with commercial software and/or open source solutions. The decisive factor for the *Imalys* concept was to bundle all necessary commands and parameters into one process that contains all sub-steps and (depending on the application) only requires location, time and resulting indicators as input. 

*Imalys* was designed as a collection of building blocks (tools) to extract defined landscape properties (traits) from public available data. The whole process chain is controlled by predefined hooks and runs without manual interaction. The tools are interchangeable and can be rearranged for new tasks. *Imalys* is available as [source code](code) and as [executable](executables) files. *Imalys* is designed to run under a server environment but can also be used on any PC.

For detailed information please refer to our [tutorials](Imalys_Tutorial.pdf), the [process description](Imalys_Process.pdf) or the [background documents](Imalys_Background.pdf) .

___


![Change](images/Hohes-Holz_Großer-Bruch.png)

*Change between spring and autumn calculated as variance during the growing seasons 2014 to 2021. The image is segmented to a seamless mosaic of zones with homogeneous features. Values calculated from Landsat-8 scenes at the Bode catchment (Saxonia, Germany). Value range [0 … 0.5] depicted as blue … red*

___


### Get Started

The easiest way to learn about *Imalys* is to run one of the [tutorials](Imalys_Tutorial.pdf). Copy and extract the [tutorial archive](tutorial.zip) to a place where you have writing permissions and follow the description. The archive includes image data, process chains, binary files and a stepwise description how to use them. The only thing you have to add is the [GDAL library](https://github.com/OSGeo/GDAL).

### Installation

The *Imalys* [binary files](binaries) need no installation. They can be simply copied to your */usr/local/bin* directory. To run *Imalys* the GDAL library must be available under your */usr/bin/* directory. The GDAL library can be obtained from [GitHub](https://github.com/OSGeo/GDAL). If you run Quantum-Gis the library is already installed. For details please refer to our [tutorials](Imalys_Tutorial.pdf).

### Usage

Each tutorial comes with explanations for this process. The tutorials describe in depth the installation, use and combination of all *Imalys* tools. For expert users the background of important algorithms is explained at the [background](Imalys_Background) document. An online documentation is available at [GitLab](Imalys_Background).

### Changelog

*Imalys* is under development. The version 0.2 was focused on methods to select and extract appropriate images from large data collections as shipped by the providers and linking them to a seamless and high quality product for a freely selectable region. A time series of the whole of Germany using TK100 sheets with approx. 50,000 image maps is an example of this intention. Tools for change detection, outliers and trends will be the next step.

All notable changes to this project will be documented in [CHANGELOG.md](CHANGELOG.md).

### Get involved

*Imalys* is the answer of our current needs to detect landscape types and their change in space and time using remote sensing data. We faced the need to process large amounts of data with as little manual interaction as possible. Our solutions are predefined process chains that return defined landscape features. We call them "traits". The process chains should be independent from scaling, geographic location and sensor properties as much as possible. The concept of these process chains and their implementation as algorithms is still under development. 

The process chains are given by hooks (commands and parameters as written text). Hooks assign import data and fix the sequence of the necessary processing steps. Hooks don't require coding expertise. New process chains and new traits can be defined only by hooks. We would like to hear of both, ideas and contribution about new processes and how they can be realized!

### Contributing

If you found a bug or want to suggest some interesting features, please refer to our [contributing guidelines](CONTRIBUTING.md) to see how you can contribute to *Imalys*.

### User support

If you need help or have a question, you can use the [Imalys user support](mailto:imalys-support@ufz.de).

### Copyright and License

Copyright(c) 2023, [Helmholtz-Zentrum für Umweltforschung GmbH -- UFZ](https://www.ufz.de). All rights reserved.

- Documentation: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/) <a rel="license" href="http://creativecommons.org/licenses/by/4.0/"><img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by/4.0/80x15.png" /></a>

- Source code: [GNU General Public License 3](https://www.gnu.org/licenses/gpl-3.0.html)

For full details, see [LICENSE](LICENSE.md).

### Acknowledgements

### Publications

Selsam P., Bumberger J., Wellmann T., Pause M., Gey R., Borg E., Lausch A.: Ecosystem Integrity Remote Sensing – Modelling and Service Tool - ESIS/Imalys,

SoftwareX: Selsam P., Lausch A., Bumberger J., Wellmann T.: Imalys – ESIS software library to extract landscape characteristics from remote sensing data

### How to cite Imalys

If Imalys is advancing your research, please cite as:

> Lausch A, Selsam P, Pause M, Bumberger J. 2024 Monitoring vegetation-and geodiversity with remote sensing and traits.Phil.Trans.R.Soc.A382: 20230058.https://doi.org/10.1098/rsta.2023.0058

See also the [CITATION.cff](CITATION.cff).

-----------------
<a href="https://www.ufz.de/index.php?en=33573">
    <img src="https://git.ufz.de/rdm-software/saqc/raw/develop/docs/resources/images/representative/UFZLogo.png" width="400"/>
</a>

<a href="https://www.ufz.de/index.php?en=45348">
    <img src="https://git.ufz.de/rdm-software/saqc/raw/develop/docs/resources/images/representative/RDMLogo.png" align="right" width="220"/>
</a>
