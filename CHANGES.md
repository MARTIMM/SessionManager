* 2025-04-23 0.4.7
  * It is now possible to display results of script, run in **SessionManager::ActionData**, in a scrollable window.
  * New version does not use images, only icons.

* 2025-03-11 0.4.6
  * Configuration changes
  * Drop the --parts option for sessions. All sessions referred from config file
  * Add variables in file and refer from config
  * Add actions in file and refer from config

* 2025-03-04 0.4.5
  * button added to run all items in a session level, TODO: not yet correct!

* 2024-09-27 0.4.4
  * Session config can be split up in session parts, stored in the Parts directory.
  * Parts and Images directories can be pointed at with an commandline option.

* 2024-09-26 0.4.3
  * Resize window after changing sessions
  * Images also found automatically

* 2024-09-24 0.4.2
  * Extension to inject variables per action and save them in the config. The variables get substituted just before execution. This is useful when other actions may depend on these variables. An example I cam across when I test the mongodb server. The command handling this has several options to select the type of server and version. So variables can be set and a server started while other actions run tests with the information set previously. This saves us a lot of test actions when the same tests must be done for different type of servers and versions.

* 2024-08-10 0.4.1
  * Add more than one layer of actions
  * Add overlayer for smaller icons displayed in the lower right corner over the larger icon. Useful to show the development projects icon with an action icon in the corner like the dolphin or konsole symbol.

* 2024-07-22 0.4.0
  * Drop use of the QA modules
  * Use the new api of Gnome::Gtk4

* 2022-08-24 0.3.2
  * QA changes

* 2022-07-18 0.3.1
  * More theming

* 2022-07-10 0.3.0
  * Setup gui
    * Has menu
    * Displays actions
    * Some theming

* 2022-07-09 0.2.0
  * Basic dispatcher reading a handwrought config and execute an action using 2 options `group` and `actions`.

* 2021-11-22 0.1.0 Start project
  * Time to make a dispatcher program to replace the `start-app.raku`.
