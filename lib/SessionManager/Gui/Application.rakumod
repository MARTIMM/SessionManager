
use v6.d;

use Getopt::Long;

use Gnome::N::N-Object:api<2>;
#use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

use Gnome::Gio::T-ioenums:api<2>;

use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Grid:api<2>;

use GnomeTools::Gio::Menu;

use GnomeTools::Gtk::Application;

use SessionManager::Actions;
use SessionManager::Sessions;
use SessionManager::Variables;
use SessionManager::Config;
use SessionManager::Gui::Toolbar;
use SessionManager::Gui::Actions;
use SessionManager::Gui::Variables;
use SessionManager::Gui::Sessions;
use SessionManager::Gui::Config;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Application:auth<github:MARTIMM>;

constant Grid = Gnome::Gtk4::Grid;

constant APP_ID is export = 'io.github.martimm.session-manager';

constant LocalOptions = [<version help|h>];
constant RemoteOptions = [ |<verbose|v legacy> ];

has GnomeTools::Gtk::Application $!application;
has Int $.exit-code = 0;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
  with $!application .= new(
    :app-id(APP_ID), :app-flags(G_APPLICATION_HANDLES_COMMAND_LINE)
  ) {
    .set-activate( self, 'app-activate');
#    .set-startup( self, 'startup');
    .set-shutdown( self, 'shutdown');

    .process-local-options( self, 'local-options');
    .process-remote-options( self, 'remote-options');

    $!exit-code = .run;
  }
}

#-------------------------------------------------------------------------------
method local-options ( --> Int ) {

  # get-options() dies when unknown options are passed
  CATCH { default { .message.note; $!exit-code = 1; return $!exit-code; } }

  # By default, continue to proces remote options and/or activation of
  # primary instance
  $!exit-code = -1;

  # Keeps all options from @*ARGS because of :!overwrite.
  # Local options which do not need a config file or primary instance
  my $o = get-options( |LocalOptions, |RemoteOptions, :!overwrite);
  if $o<version> {
    say "Version of dispatcher is $*manager-version";
    $!exit-code = 0;
  }

  if $o<h>:exists or $o<help>:exists {
    # When set to 1, the main program will always show the help message
    $!exit-code = 1;
  }

  $!exit-code
}

#-------------------------------------------------------------------------------
method remote-options ( Array $args, Bool :$is-remote --> Int ) {
  $!exit-code = 0;
note "$?LINE $args.gist()";

  # Eats all options from @*ARGS by :overwrite
  my Capture $o = get-options-from( $args, |RemoteOptions, :overwrite);
note "$?LINE $args.gist()";
  if $o<verbose>:exists {
    $*verbose = True;
  }

  if ?$o<legacy> {
    $*legacy = ?$o<legacy>;
  }

  if ?@$args {
    $*config-directory = $args[1];
    if $*config-directory.IO.absolute.Str eq
       "$*HOME/Languages/Raku/Projects/SessionManager"
    {
      $!exit-code = 1;
      note "\nConfiguration path '$*config-directory' cannot be in my projects dir";
    }

    elsif $*config-directory.IO ~~ :d {
      # Now initialize configuration.
      my SessionManager::Config $config .= instance(:reinit);
      $!application.set-window-content(
        self.window-content, self.menu, :title($config.get-window-title)
      );

      # finish up
#      $!application.activate unless $is-remote;
    }

    else {
      $!exit-code = 1;
      note "\nConfiguration path '$*config-directory' is not a directory (or wrong one)";
    }
  }

  else {
    $!exit-code = 1;
    note "\nYou must specify a sesion directory";
  }

  $!exit-code
}

#-------------------------------------------------------------------------------
method shutdown ( ) {
  self.save-config unless $!exit-code;
}

#-------------------------------------------------------------------------------
# Called after registration of the application
#method startup ( ) {
#}

#-------------------------------------------------------------------------------
# Activation of the application takes place when processing remote options
# reach the default entry, or when setup options are processed.
# And when this process is also the primary instance, it's only called once
# because we don't need to create two gui's. This is completely automatically
# done.
method app-activate ( ) {
#  my SessionManager::Config $config .= instance;
#  $!application.set-window-content(
#    self.window-content, self.menu, :title($config.get-window-title)
#  );
}

#-------------------------------------------------------------------------------
method window-content ( --> Grid ) {

  # Use of grid makes it easier to remove boxes from the grid later on
  my Grid $session-manager-box .= new-grid;
  my SessionManager::Gui::Toolbar $toolbar .= new-scrolledwindow(
    :$session-manager-box #, :$!app-window
  );
  $session-manager-box.attach( $toolbar, 0, 0, 1, 1);

  $session-manager-box
}

#-------------------------------------------------------------------------------
method menu ( --> GnomeTools::Gio::Menu ) {

  my SessionManager::Gui::Actions $action-edit .= instance;
  my SessionManager::Gui::Variables $variable-edit .= instance;
  my SessionManager::Gui::Sessions $session-edit .= instance;
  my SessionManager::Gui::Config $config-edit .= instance;

  my GnomeTools::Gio::Menu $bar .= new;
  my GnomeTools::Gio::Menu $parent-menu = $bar;
  with my GnomeTools::Gio::Menu $m1 .= new( :$parent-menu, :name<File>) {
    $parent-menu = $m1;
    with my GnomeTools::Gio::Menu $sc1 .= new( :$parent-menu, :section(Str)) {
      .item( 'Modify Configuration', $config-edit, 'modify-configuration');
      .item( 'Restart', self, 'file-restart');
    }
    with my GnomeTools::Gio::Menu $sc2 .= new( :$parent-menu, :section(Str)) {
      .item( 'Quit', self, 'file-quit');
    }
  }

  $parent-menu = $bar;
  with my GnomeTools::Gio::Menu $m2 .= new( :$parent-menu, :name<Sessions>) {
    .item( 'Add/Rename', $session-edit, 'add-rename');
    .item( 'Add/Rename Group', $session-edit, 'add-rename-group');
    .item( 'Delete Group', $session-edit, 'delete-group');
    .item( 'Add/Remove Actions', $session-edit, 'add-remove-actions');
    .item( 'Delete', $session-edit, 'delete');
  }

  with my GnomeTools::Gio::Menu $m3 .= new( :$parent-menu, :name<Actions>) {
    .item( 'Create', $action-edit, 'create-action');
    .item( 'Modify', $action-edit, 'modify-action');
    .item( 'Rename id', $action-edit, 'rename-id');
    .item( 'Delete', $action-edit, 'delete');
  }

  with my GnomeTools::Gio::Menu $m4 .= new( :$parent-menu, :name<Variables>) {
    .item( 'Add Modify', $variable-edit, 'add-modify');
    .item( 'Delete', $variable-edit, 'delete');
  }
  
  $bar
}

#-------------------------------------------------------------------------------
method file-restart ( N-Object $parameter ) {
  say 'file restart';

  self.save-config;

  my SessionManager::Config $config .= instance;
  $!application.set-window-content(
    self.window-content, self.menu, :title($config.get-window-title)
  );
}

#-------------------------------------------------------------------------------
method file-quit ( N-Object $parameter ) {
  $!application.quit;
}

#-------------------------------------------------------------------------------
method save-config ( ) {
  # save changed config
  my SessionManager::Variables $variables .= new;
  my SessionManager::Actions $actions .= new;
  my SessionManager::Sessions $sessions .= new;
  $actions.save;
  $variables.save;
  $sessions.save;
}



























=finish
use NativeCall;

use Getopt::Long;

use GnomeTools::Gio::Menu;

use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Application:api<2>;
use Gnome::Gtk4::ApplicationWindow:api<2>;

use Gnome::Glib::T-error:api<2>;

use Gnome::N::N-Object:api<2>;
#use Gnome::N::X:api<2>;
#Gnome::N::debug(:on);

use SessionManager::Actions;
use SessionManager::Sessions;
use SessionManager::Variables;
use SessionManager::Config;
use SessionManager::Gui::Toolbar;
use SessionManager::Gui::Actions;
use SessionManager::Gui::Variables;
use SessionManager::Gui::Sessions;
use SessionManager::Gui::Config;

use Gnome::Gio::T-ioenums:api<2>;
use Gnome::Gio::ApplicationCommandLine:api<2>;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Application:auth<github:MARTIMM>;

constant APP_ID is export = 'io.github.martimm.session-manager';

constant Grid = Gnome::Gtk4::Grid;
constant LocalOptions = [<version h help>];
constant RemoteOptions = [ |<v verbose legacy> ];
#constant RemoteOptions = [ |<v verbose legacy m load-manual-build-config> ];

has Gnome::Gtk4::Application $.application;
has Gnome::Gtk4::ApplicationWindow $.app-window;

#-------------------------------------------------------------------------------
submethod BUILD ( ) {
# $!dispatch-testing = True;

  $!application .= new-application(
    APP_ID, G_APPLICATION_HANDLES_COMMAND_LINE
  );

  # Register all necessary signals
  $!application.register-signal( self, 'app-activate', 'activate');
  $!application.register-signal( self, 'local-options', 'handle-local-options');
  $!application.register-signal( self, 'remote-options', 'command-line');
  $!application.register-signal( self, 'startup', 'startup');
  $!application.register-signal( self, 'shutdown', 'shutdown');

  # Save when an interrupt arrives
  signal(SIGINT).tap( {
      exit 0;
    }
  );

  # Now we can register the application.
  my $e = CArray[N-Error].new(N-Error);
  $!application.register( N-Object, $e);
  die $e[0].message if ?$e[0];
}

#-------------------------------------------------------------------------------
method go-ahead ( --> Int ) {
  my Int $argc = 1 + @*ARGS.elems;

  my $arg_arr = CArray[Str].new();
  $arg_arr[0] = $*PROGRAM.Str;
  my Int $arg-count = 1;
  for @*ARGS -> $arg {
    $arg_arr[$arg-count++] = $arg;
  }

  my $argv = CArray[Str].new($arg_arr);

  $!application.run( $argc, $argv)
}

#-------------------------------------------------------------------------------
method local-options ( N-Object $no-vd --> Int ) {
  # By default, continue to proces remote options and/or activation of
  # primary instance
  my Int $exit-code = -1;

  CATCH { default { .message.note; $exit-code = 1; return $exit-code; } }

  # Local options which do not need a config file or primary instance
  my $o = get-options( |LocalOptions, |RemoteOptions);
  if $o<version> {
    say "Version of dispatcher is $*manager-version";
    $exit-code = 0;
  }

  if $o<h>:exists or $o<help>:exists {
    # When set to 1, the main program will always show the help message
    $exit-code = 1;
  }

  if $exit-code == -1 {
    $exit-code = 2;
  }

  $exit-code
}

#-------------------------------------------------------------------------------
method remote-options ( Gnome::Gio::ApplicationCommandLine() $cl --> Int ) {

  my Array $args = $cl.get-arguments;
  my Capture $o = get-options-from( $args[1..*-1], |RemoteOptions);

  if $o<v>:exists or $o<verbose>:exists {
    $*verbose = True;
  }

  unless ?$!app-window and $!app-window.is-valid {
    # Check all arguments, skip first arg, $args[0] == programname
    for $args[1..*-1] -> $a {

      # Skip all options starting with a '-'
      if $a !~~ m/^ '-' / {
        # Only one argument possible
        $*config-directory = $a;

        # And must be a directory
        if $*config-directory.IO !~~ :d {
          note "\nConfiguration directory '$*config-directory' not found";
          return 1;
        }
        last;
      }
    }

    # if name is empty -> error
    if !$*config-directory {
      note "\nYou must specify a sesion directory";
      return 1;
    }

#`{{
    my Bool $load-manual-build-config = False;
    if $o<m>:exists or $o<load-manual-build-config>:exists {
      $load-manual-build-config = $o<load-manual-build-config>.Bool;
    }
    my SessionManager::Config $config .= instance(:$load-manual-build-config);
}}
    my SessionManager::Config $config .= instance;

    if ?$o<legacy> {
      $*legacy = ?$o<legacy>;
    }
  }

  # finish up
  if $cl.get-is-remote {
#    self.setup-window;
  }

  else {
    $!application.activate;
  }

  $cl.done;
  $cl.clear-object;
  0
}

#-------------------------------------------------------------------------------
#-- [callback handlers] --------------------------------------------------------
#-------------------------------------------------------------------------------
# Called after registration of the application
method startup ( ) {
}

#-------------------------------------------------------------------------------
# Activation of the application takes place when processing remote options
# reach the default entry, or when setup options are processed.
# And when this process is also the primary instance, it's only called once
# because we don't need to create two gui's. This is completely automatically
# done.
method app-activate ( ) {
  self.setup-window;
}

#-------------------------------------------------------------------------------
method setup-window ( ) {

#`{{
  if ?$!app-window and $!app-window.is-valid {
    $!application.remove-window($!app-window);
    $!app-window.destroy;
    $!app-window.clear-object;
  }
}}

  # Set the theme and initialize application window and give this object (a
  # Gnome::Gtk4::Application) as its argument.
  with $!app-window .= new-applicationwindow($!application) {

    # Use of grid makes it easier to remove boxes from the grid later on
    my Grid $session-manager-box .= new-grid;
    my SessionManager::Gui::Toolbar $toolbar .= new-scrolledwindow(
      :$session-manager-box, :$!app-window
    );
    $session-manager-box.attach( $toolbar, 0, 0, 1, 1);

    my SessionManager::Config $config .= instance;

    my GnomeTools::Gio::Menu $menu-bar = self.make-menu;
    $menu-bar.set-actions($!application);
    $!application.set-menubar($menu-bar.get-menu);
    .set-show-menubar(True);
#    .set-valign(GTK_ALIGN_FILL);

    .set-title($config.get-window-title);
    .set-child($session-manager-box);

#    .set-default-size($config.get-window-size);

    .present;
  }
}

#-------------------------------------------------------------------------------
method make-menu ( --> GnomeTools::Gio::Menu ) {

  my SessionManager::Gui::Actions $action-edit .= instance;
  my SessionManager::Gui::Variables $variable-edit .= instance;
  my SessionManager::Gui::Sessions $session-edit .= instance;
  my SessionManager::Gui::Config $config-edit .= instance;

  my GnomeTools::Gio::Menu $bar .= new;
  my GnomeTools::Gio::Menu $parent-menu = $bar;
  with my GnomeTools::Gio::Menu $m1 .= new( :$parent-menu, :name<File>) {
    $parent-menu = $m1;
    with my GnomeTools::Gio::Menu $sc1 .= new( :$parent-menu, :section(Str)) {
      .item( 'Modify Configuration', $config-edit, 'modify-configuration');
      .item( 'Restart', self, 'file-restart');
    }
    with my GnomeTools::Gio::Menu $sc2 .= new( :$parent-menu, :section(Str)) {
      .item( 'Quit', self, 'file-quit');
    }
  }

  $parent-menu = $bar;
  with my GnomeTools::Gio::Menu $m2 .= new( :$parent-menu, :name<Sessions>) {
    .item( 'Add/Rename', $session-edit, 'add-rename');
    .item( 'Add/Rename Group', $session-edit, 'add-rename-group');
    .item( 'Delete Group', $session-edit, 'delete-group');
    .item( 'Add/Remove Actions', $session-edit, 'add-remove-actions');
    .item( 'Delete', $session-edit, 'delete');
  }

  with my GnomeTools::Gio::Menu $m3 .= new( :$parent-menu, :name<Actions>) {
    .item( 'Create', $action-edit, 'create-action');
    .item( 'Modify', $action-edit, 'modify-action');
    .item( 'Rename id', $action-edit, 'rename-id');
    .item( 'Delete', $action-edit, 'delete');
  }

  with my GnomeTools::Gio::Menu $m4 .= new( :$parent-menu, :name<Variables>) {
    .item( 'Add Modify', $variable-edit, 'add-modify');
    .item( 'Delete', $variable-edit, 'delete');
  }
  
  $bar
}

#-------------------------------------------------------------------------------
method file-restart ( N-Object $parameter ) {
  say 'file restart';

  self.save-config;

  if ?$!app-window and $!app-window.is-valid {
    $!application.remove-window($!app-window);
    $!app-window.destroy;
    $!app-window.clear-object;
  }

  self.setup-window;
}

#-------------------------------------------------------------------------------
method file-quit ( N-Object $parameter ) {
  $!application.quit;
}

#-------------------------------------------------------------------------------
method shutdown ( ) {
  self.save-config;
}

#-------------------------------------------------------------------------------
method save-config ( ) {
  # save changed config
  my SessionManager::Variables $variables .= new;
  my SessionManager::Actions $actions .= new;
  my SessionManager::Sessions $sessions .= new;
  $actions.save;
  $variables.save;
  $sessions.save;
}
