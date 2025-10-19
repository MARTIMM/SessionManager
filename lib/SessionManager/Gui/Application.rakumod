
use v6.d;

use NativeCall;

use Getopt::Long;

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

use GnomeTools::Gtk::Menu;

use Gnome::Gio::T-ioenums:api<2>;
use Gnome::Gio::ApplicationCommandLine:api<2>;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::Application:auth<github:MARTIMM>;

constant APP_ID is export = 'io.github.martimm.session-manager';

constant Grid = Gnome::Gtk4::Grid;
constant LocalOptions = [<version h help>];
constant RemoteOptions = [ |<v verbose legacy m load-manual-build-config> ];

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

  $!application.run( $argc, $argv);
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

  $exit-code
}

#-------------------------------------------------------------------------------
method remote-options ( Gnome::Gio::ApplicationCommandLine() $cl --> Int ) {

  my Array $cmd-list = [];

  my Array $args = $cl.get-arguments;
  my Capture $o = get-options-from( $args[1..*-1], |RemoteOptions);

  if $o<v>:exists or $o<verbose>:exists {
    $*verbose = True;
  }

  unless ?$!app-window and $!app-window.is-valid {
    for $args[1..*-1] -> $a {
      if $a !~~ m/^ '-' / {
        $*config-directory = $a;

        if $*config-directory.IO !~~ :d {
          note "\nConfiguration directory '$*config-directory' not found";
          return 1;
        }
        last;
      }
    }

    if !$*config-directory {
      note "\nYou must specify a sesion directory";
      return 1;
    }

    my Bool $load-manual-build-config = False;
    if $o<m>:exists or $o<load-manual-build-config>:exists {
      $load-manual-build-config = $o<load-manual-build-config>.Bool;
    }
    my SessionManager::Config $config .= instance(:$load-manual-build-config);

    if ?$o<legacy> {
      $*legacy = True;
      $config.set-legacy(True);
    }
  }

  # finish up
  if $cl.get-is-remote {
    self.setup-window;
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

  # Set the theme and initialize application window and give this object (a
  # Gnome::Gtk4::Application) as its argument.
  if ?$!app-window and $!app-window.is-valid {
    $!application.remove-window($!app-window);
    $!app-window.destroy;
    $!app-window.clear-object;
  }

  with $!app-window .= new-applicationwindow($!application) {

    # Use of grid makes it easier to remove boxes from the grid later on
    my Grid $session-manager-box .= new-grid;
    my SessionManager::Gui::Toolbar $toolbar .= new-box(
      GTK_ORIENTATION_VERTICAL, 1, :$session-manager-box, :$!app-window
    );
    $session-manager-box.attach( $toolbar, 0, 0, 1, 1);

    my SessionManager::Config $config .= instance;

    my GnomeTools::Gtk::Menu $menu-bar = self.make-menu;
    $menu-bar.set-actions($!application);
    $!application.set-menubar($menu-bar.get-menu);
    .set-show-menubar(True);
    .set-valign(GTK_ALIGN_FILL);

    .set-title($config.get-window-title);
    .set-child($session-manager-box);

    .set-default-size($config.get-window-size);

    .present;
  }
}

#-------------------------------------------------------------------------------
method make-menu ( --> GnomeTools::Gtk::Menu ) {

  my SessionManager::Gui::Actions $action-edit .= instance;
  my SessionManager::Gui::Variables $variable-edit .= instance;
  my SessionManager::Gui::Sessions $session-edit .= instance;
  my SessionManager::Gui::Config $config-edit .= instance;

  my GnomeTools::Gtk::Menu $bar .= new;
  my GnomeTools::Gtk::Menu $parent-menu = $bar;
  with my GnomeTools::Gtk::Menu $m1 .= new( :$parent-menu, :name<File>) {
    $parent-menu = $m1;
    with my GnomeTools::Gtk::Menu $sc1 .= new( :$parent-menu, :section(Str)) {
      .item( 'Modify Configuration', $config-edit, 'modify-configuration');
      .item( 'Restart', self, 'file-restart');
    }
    with my GnomeTools::Gtk::Menu $sc2 .= new( :$parent-menu, :section(Str)) {
      .item( 'Quit', self, 'file-quit');
    }
  }

  $parent-menu = $bar;
  with my GnomeTools::Gtk::Menu $m2 .= new( :$parent-menu, :name<Sessions>) {
    .item( 'Add/Rename', $session-edit, 'add-rename');
    .item( 'Add/Rename Group', $session-edit, 'add-rename-group');
    .item( 'Delete Group', $session-edit, 'delete-group');
    .item( 'Add/Remove Actions', $session-edit, 'add-remove-actions');
    .item( 'Delete', $session-edit, 'delete');
  }

  with my GnomeTools::Gtk::Menu $m3 .= new( :$parent-menu, :name<Actions>) {
    .item( 'Create', $action-edit, 'create');
    .item( 'Modify', $action-edit, 'modify');
    .item( 'Rename id', $action-edit, 'rename-id');
    .item( 'Delete', $action-edit, 'delete');
  }

  with my GnomeTools::Gtk::Menu $m4 .= new( :$parent-menu, :name<Variables>) {
    .item( 'Add Modify', $variable-edit, 'add-modify');
    .item( 'Delete', $variable-edit, 'delete');
  }
  
  $bar
}

#-------------------------------------------------------------------------------
method file-restart ( N-Object $parameter ) {
  say 'file restart';
  self.save-config;
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
