# Dispatcher Application

## Synopsis

SessionManager - A program to start session environments


## Documentation

### What should it NOT do?

The program should not show an application menu. Those kind of programs are already provided by the window managers. So that wheel will not be reinvented!

### What should it do?

The purpose of this program is that it can quickly setup an environment for something like a programming or music writing task.

In the case of a programming task; 
  * start a console with several tabs open to working directories
  * start an editor
  * start a filemanager with tabs opened to directories
  * start a reader with some language documentation, etcetera

There is only one session manager instance running. All other instances started later will communicate with the main running program. This might replace the current view with another depending on provided configuration.

<!--
The default config directory will be at `~/.config/io.github.martimm.sessionmanager` where also some program images and style files are stored.

Example useage;
```
> mkdir ~/MyDispatchEnv
> cd ~/MyDispatchEnv
> vi dispatch-config.yaml
…
> mkdir Images
… import some images referenced by the config file …
> dispatcher --config=~/MyDispatchEnv
```



## Installing the modules

Use zef to install the package and programs.

```
> zef install SessionManager
```


# Other dependencies

* A desktop manager on Linux, so it is not usable on Windows.


## Versions of Raku, MOARVM

This project is tested with Rakudo built on MoarVM implementing Perl v6.d.


## Author

* Marcel Timmerman, github accountname [MARTIMM](https://github.com/MARTIMM)


## Attribution

* [stock.adobe.com config icon](https://stock.adobe.com/images/id/148661655?as_campaign=Flaticon&as_content=api&as_audience=srp&tduid=be971cf7dacd43f1e5e378060daf8732&as_channel=affiliate&as_campclass=redirect&as_source=arvato&asset_id=144547159)

* [Brands and logotypes icons created by Freepik - Flaticon](https://www.flaticon.com/free-icons/github)

* <a target="_blank" href="https://icons8.com/icon/9OGIyU8hrxW5/visual-studio-code-2019">visual studio code</a> icon by <a target="_blank" href="https://icons8.com">Icons8</a>

* <a href="https://www.flaticon.com/free-icons/folder" title="folder icons">Folder icons created by Freepik - Flaticon</a>

* [Svg Repository](https://www.svgrepo.com).
