# Dispatcher Application

## Synopsis

Dispatcher - A program to start an application setup


## Documentation

Some thoughts …


### What should it NOT do?

The program should not show an application menu. Those kind of programs are already provided by the window managers in several forms. So that wheel will not be reinvented!


### What should it do?

The purpose of this program is that it can quickly setup or change an environment for something like a programming or music writing task.

In the case of a programming task; start a console with several tabs open to working directories, start an editor, start a filemanager with tabs opened to directories, start a reader with some language documentation, etcetera.

Optionally the action can show a checkbutton for each program which can be (de)selected to dis-/enable the start of a program depending on what is needed at that moment. *this is something for later.*

The program must therefore show a dispatcher page showing a shallow tree. The actions are at the leafs of the tree and the parents of those actions function as a grouping for those actions. The difference compared to the application menu is that an action can do more than only start one application or script.

There is only one dispatcher instance running. All other instances started later will communicate with the main running program.

DBus will play a part by sending commands to the activated parts. This function can check if apps are started, send commands to change, etcetera. *this is something for later.*

There is a configuration section to create the configuration file. *this is something for later, first read from configurations made by hand.*


### Application workings

A description follows what this program should show and do.

#### Startup options
* Option pointing to an alternative configuration file. The default configuration file is stored at `$XDG_CONFIG ?` or at the config root `~/.config/`.
  * Several other files may exist such as a theme description. This can be defined in the configuration file. When absent, the current desktop theme is used.
  ```
  ~/.config/io.github.martimm.dispatcher/
    Data.d/
      theme.yaml                        Theme description
      dispatch.yaml                     The config to use with dispatch info
    Sheets.d/
      dispatch.yaml                     The questionaire to describe an action
  ```
  * The configuration files are all in a YAML formatted file.

* Option to start an action directly. This option is repeatable.

#### User interface
* Menu bar on top
  * Exit          (Save config)
  * Quit          (No save of config)
  * Help
  * About

  * Configuration
    * Save configuration
    * Select a different configuration file
    * Configure dispatch action
  * Action
    * Create
    * Modify
    * Delete
  * Action Map
    * Create
    * Modify
    * Delete

* A treeview of actions

* A configuration page when action is created or changed


### Build phases

#### Start with non-gui application.
* [x] install options
* [x] create config files
* [x] test run to start an action

#### Make application sceleton
* [x] hook up options
* [x] test run to start main dispatcher
* [x] test run to start an action from secondary dispatcher

#### Show menu
* [x] Add simple menu entries

#### Show actions
* [x] Display of actions
* [x] Activation of actions
* [ ] Add more menu entries

#### Modify actions
* [ ] Display of action config
* [ ] Add more menu entries


## Installing the modules

Use zef to install the package and programs.

```
> zef install Dispatcher
```


# (Non-) Raku dependencies

* QA - a Question and Answer package which in turn depend on Gnome::* packages.
* KDE - A desktop manager on Linux, so it is probably not usable on Windows.


## Versions of PERL, MOARVM

This project is tested with Rakudo built on MoarVM implementing Perl v6.


## Authors

* Marcel Timmerman, github accountname [MARTIMM](https://github.com/MARTIMM)


## Attribution

* A [stock.adobe.com config icon](https://stock.adobe.com/images/id/148661655?as_campaign=Flaticon&as_content=api&as_audience=srp&tduid=be971cf7dacd43f1e5e378060daf8732&as_channel=affiliate&as_campclass=redirect&as_source=arvato&asset_id=144547159)
